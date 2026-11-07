locals {
  regions = {
    aue = "austriaeast"
    cac = "canadacentral"
    onp = "westeurope"
  }

  tags = {
    environment = "lab"
    project     = "azure-hybrid-network"
    purpose     = "hybrid-network-lab"
    owner       = var.owner
    managed_by  = "terraform"
  }

  aue_cidr = "10.10.0.0/16"
  cac_cidr = "10.20.0.0/16"
  onp_cidr = "192.168.0.0/16"

  onp_subnet_cidr = "192.168.1.0/24"

  # Azure's implicit AllowVnetInBound would otherwise open every port to peered
  # networks, VPN clients and on-premises, so each NSG ends with an explicit deny.
  # A new internal flow, such as SQL on 1433, needs its own allow rule.
  deny_other_vnet_inbound = {
    DenyOtherVirtualNetworkInbound = {
      priority                = 4000
      protocol                = "*"
      source_address_prefixes = ["VirtualNetwork"]
      destination_port_ranges = ["*"]
      access                  = "Deny"
    }
  }

  azure_nsg_rules = merge(local.deny_other_vnet_inbound, {
    AllowWebFromFrontDoor = {
      priority                = 100
      protocol                = "Tcp"
      source_address_prefixes = ["AzureFrontDoor.Backend"]
      destination_port_ranges = ["80", "443"]
    }
    AllowAdminFromAdminNetworks = {
      priority                = 110
      protocol                = "Tcp"
      source_address_prefixes = [var.p2s_address_pool, local.onp_cidr]
      destination_port_ranges = ["3389", "80", "443"]
    }
    AllowPingFromAdminNetworks = {
      priority                = 120
      protocol                = "Icmp"
      source_address_prefixes = [var.p2s_address_pool, local.onp_cidr]
      destination_port_ranges = ["*"]
    }
  })

  onp_nsg_rules = merge(
    local.deny_other_vnet_inbound,
    {
      AllowRdpFromP2sClients = {
        priority                = 100
        protocol                = "Tcp"
        source_address_prefixes = [var.p2s_address_pool]
        destination_port_ranges = ["3389"]
      }
      AllowPingFromAzureNetworks = {
        priority                = 105
        protocol                = "Icmp"
        source_address_prefixes = [local.aue_cidr, local.cac_cidr, var.p2s_address_pool]
        destination_port_ranges = ["*"]
      }
      # vm-clt-001 sends Azure-bound traffic through vm-fw-001 on this subnet.
      AllowOnPremisesSubnet = {
        priority                = 130
        protocol                = "*"
        source_address_prefixes = [local.onp_subnet_cidr]
        destination_port_ranges = ["*"]
      }
    },
    var.admin_source_cidr == null ? {} : {
      AllowRdpFromAdminIp = {
        priority                = 110
        protocol                = "Tcp"
        source_address_prefixes = [var.admin_source_cidr]
        destination_port_ranges = ["3389"]
      }
    }
  )

  networks = {
    aue = {
      name           = "vnet-lab-aue-001"
      resource_group = azurerm_resource_group.lab.name
      region         = local.regions.aue
      address_space  = [local.aue_cidr]
      nsg_name       = "nsg-lab-aue-001"
      nsg_rules      = local.azure_nsg_rules
      subnets = {
        "snet-lab-aue-001" = { address_prefix = "10.10.1.0/24", nsg_enabled = true }
        "snet-lab-aue-002" = { address_prefix = "10.10.2.0/24", nsg_enabled = true, delegation = "Microsoft.Web/serverFarms" }
        # Reserved for the gateway, which has its own public IP; left at Azure's classic default.
        "GatewaySubnet" = { address_prefix = "10.10.3.0/24", default_outbound_access_enabled = true }
      }
    }
    cac = {
      name           = "vnet-lab-cac-001"
      resource_group = azurerm_resource_group.lab.name
      region         = local.regions.cac
      address_space  = [local.cac_cidr]
      nsg_name       = "nsg-lab-cac-001"
      nsg_rules      = local.azure_nsg_rules
      subnets = {
        "snet-lab-cac-001"     = { address_prefix = "10.20.1.0/24", nsg_enabled = true }
        "snet-lab-cac-002"     = { address_prefix = "10.20.2.0/24", nsg_enabled = true, delegation = "Microsoft.Web/serverFarms" }
        "snet-pvtendp-cac-003" = { address_prefix = "10.20.3.0/24" }
      }
    }
    onp = {
      name           = "vnet-onpremises"
      resource_group = azurerm_resource_group.onp.name
      region         = local.regions.onp
      address_space  = [local.onp_cidr]
      nsg_name       = "nsg-onp-001"
      nsg_rules      = local.onp_nsg_rules
      subnets = {
        # vm-clt-001 has no public IP but still needs internet access for updates.
        "snet-onpremises" = { address_prefix = local.onp_subnet_cidr, nsg_enabled = true, default_outbound_access_enabled = true }
      }
    }
  }

  vms = {
    "vm-srv-aue-001" = { network = "aue", subnet = "snet-lab-aue-001", public_ip = true, web_server = true }
    "vm-app-cac-001" = { network = "cac", subnet = "snet-lab-cac-001", public_ip = true, web_server = true }
    "vm-fw-001"      = { network = "onp", subnet = "snet-onpremises", public_ip = true, ip_forwarding = true, private_ip = "192.168.1.4" }
    "vm-clt-001"     = { network = "onp", subnet = "snet-onpremises" }
  }

  web_server_vms = { for name, vm in local.vms : name => vm if try(vm.web_server, false) }
}
