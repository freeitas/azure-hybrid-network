# Runs without Azure access: providers are mocked and every run is plan-only.
# Each assertion encodes a defect found in the original scripts, or a design rule.

mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id       = "00000000-0000-0000-0000-000000000001"
      object_id       = "00000000-0000-0000-0000-000000000002"
      client_id       = "00000000-0000-0000-0000-000000000003"
      subscription_id = "00000000-0000-0000-0000-000000000004"
    }
  }
}

mock_provider "random" {}
mock_provider "time" {}

variables {
  owner             = "test"
  admin_username    = "labadmin"
  alert_email       = "alerts@example.com"
  budget_start_date = "2026-12-01T00:00:00Z"
}

run "network_matches_the_requirements" {
  command = plan

  assert {
    condition     = module.network["aue"].name == "vnet-lab-aue-001" && contains(module.network["aue"].address_space, "10.10.0.0/16")
    error_message = "The Austria VNet must keep its name and address space."
  }

  assert {
    condition     = module.network["cac"].name == "vnet-lab-cac-001" && contains(module.network["cac"].address_space, "10.20.0.0/16")
    error_message = "The Canada VNet must keep its name and address space."
  }

  assert {
    condition     = module.network["onp"].name == "vnet-onpremises" && contains(module.network["onp"].address_space, "192.168.0.0/16")
    error_message = "The on-premises VNet must use the corrected spelling."
  }

  assert {
    condition     = contains(keys(module.network["aue"].subnet_ids), "GatewaySubnet")
    error_message = "Azure requires the gateway subnet to be named GatewaySubnet."
  }

  assert {
    condition     = !contains(module.network["aue"].nsg_subnet_names, "GatewaySubnet")
    error_message = "Azure does not support an NSG on GatewaySubnet."
  }
}

run "hub_transit_reaches_on_premises" {
  command = plan

  assert {
    condition     = azurerm_virtual_network_peering.aue_to_cac.allow_gateway_transit && azurerm_virtual_network_peering.aue_to_cac.allow_forwarded_traffic
    error_message = "The gateway side must offer transit and accept forwarded traffic."
  }

  assert {
    condition     = azurerm_virtual_network_peering.cac_to_aue.use_remote_gateways && azurerm_virtual_network_peering.cac_to_aue.allow_forwarded_traffic
    error_message = "The Canada side must use the remote gateway and accept forwarded traffic."
  }

  assert {
    condition     = module.vm["vm-fw-001"].ip_forwarding_enabled
    error_message = "The on-premises firewall must forward traffic."
  }

  assert {
    condition     = length(azurerm_route_table.onp.route) == 3
    error_message = "On-premises needs routes to both VNets and the P2S pool."
  }

  assert {
    condition     = module.hybrid_vpn[0].sku == "VpnGw1AZ"
    error_message = "New non-AZ gateway SKUs can no longer be created."
  }
}

run "rdp_is_never_open_to_the_internet" {
  command = plan

  assert {
    condition = alltrue(flatten([
      for network in module.network : [
        for rule in values(network.nsg_rules) :
        !(contains(rule.destination_port_ranges, "3389") && length(setintersection(rule.source_address_prefixes, ["*", "Internet", "0.0.0.0/0"])) > 0)
      ]
    ]))
    error_message = "No NSG rule may allow RDP from the internet."
  }

  assert {
    condition     = !module.vm["vm-clt-001"].has_public_ip
    error_message = "The on-premises client must not have a public IP."
  }
}

run "internal_traffic_is_allow_listed" {
  command = plan

  assert {
    condition = alltrue([
      for network in module.network :
      network.nsg_rules["DenyOtherVirtualNetworkInbound"].access == "Deny"
      && network.nsg_rules["DenyOtherVirtualNetworkInbound"].source_address_prefixes == tolist(["VirtualNetwork"])
    ])
    error_message = "Every NSG must override Azure's implicit AllowVnetInBound."
  }

  assert {
    condition     = contains(keys(module.network["onp"].nsg_rules), "AllowOnPremisesSubnet")
    error_message = "vm-clt-001 must still reach vm-fw-001 on its own subnet."
  }
}

run "wide_admin_cidr_is_rejected" {
  command = plan

  variables {
    admin_source_cidr = "0.0.0.0/0"
  }

  expect_failures = [var.admin_source_cidr]
}

run "public_web_traffic_comes_from_front_door_only" {
  command = plan

  assert {
    condition = alltrue([
      for name in ["aue", "cac"] :
      module.network[name].nsg_rules["AllowWebFromFrontDoor"].source_address_prefixes == tolist(["AzureFrontDoor.Backend"])
    ])
    error_message = "Web ports must only accept the Front Door service tag."
  }
}

run "vms_match_the_requirements" {
  command = plan

  assert {
    condition     = alltrue([for vm in module.vm : vm.os_disk_type == "StandardSSD_LRS"])
    error_message = "The requested Standard SSD disk must be set explicitly."
  }

  assert {
    condition     = length(module.vm) == 4
    error_message = "The diagram has four VMs, including vm-clt-001."
  }
}

run "file_storage_is_private_and_gallery_storage_is_reachable" {
  command = plan

  assert {
    condition     = module.storage_files.public_network_access == "Disabled" && module.storage_files.has_private_endpoint
    error_message = "The file share account must only be reachable through its private endpoint."
  }

  assert {
    condition     = module.storage_blob.public_network_access == "Enabled" && !module.storage_blob.has_private_endpoint
    error_message = "The gallery runs in the visitor's browser, so its account must stay reachable."
  }
}

run "backup_vaults_are_regional" {
  command = plan

  assert {
    condition     = module.backup["aue"].location == "austriaeast" && module.backup["cac"].location == "canadacentral"
    error_message = "Each vault must share a region with what it protects."
  }
}

run "turning_off_the_vpn_first_releases_the_remote_gateway" {
  command = plan

  variables {
    vpn_transit_enabled = false
  }

  assert {
    condition     = !azurerm_virtual_network_peering.cac_to_aue.use_remote_gateways && azurerm_virtual_network_peering.aue_to_cac.allow_gateway_transit
    error_message = "The first step must clear use_remote_gateways while transit stays on."
  }

  assert {
    condition     = length(module.hybrid_vpn) == 1
    error_message = "The first step must keep the gateway."
  }
}

run "vpn_can_be_turned_off_to_save_cost" {
  command = plan

  variables {
    vpn_enabled = false
  }

  assert {
    condition     = length(module.hybrid_vpn) == 0 && length(azurerm_virtual_machine_run_command.rras) == 0
    error_message = "Disabling the VPN must remove the gateway and tunnel."
  }

  assert {
    condition     = !azurerm_virtual_network_peering.aue_to_cac.allow_gateway_transit && !azurerm_virtual_network_peering.cac_to_aue.use_remote_gateways
    error_message = "Peering must not reference a gateway that does not exist."
  }
}
