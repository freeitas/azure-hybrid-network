# Azure hybrid network lab: Terraform

Builds the full target architecture, which the original scripts only partly covered. The target diagram is in [the analysis and plan](../docs/analysis-and-improvement-plan.md), and the before-and-after record is in [the improvement story](../docs/improvement-story/README.md).

**Status:** static checks and mock-provider tests pass, but this has never been applied to Azure. See [Not proven yet](#not-proven-yet).

## Layout

| Path | Purpose |
|---|---|
| `bootstrap/` | Terraform state storage, with its own local state |
| `envs/lab/` | Root module, wiring all resources, plus tests in `tests/` |
| `modules/` | `network`, `windows_vm`, `web_app`, `hybrid_vpn`, `storage`, `front_door`, `backup` |
| `scripts/` | PowerShell run on VMs through Run Command |

## Before you start

- Terraform 1.10 or later, and Azure CLI signed in with `az login`.
- **Owner** on the subscription, or Contributor plus User Access Administrator. Terraform creates role assignments.
- Check capacity first, because region and subscription limits vary:

```bash
az vm list-skus --location austriaeast --size Standard_B2ls_v2 --output table
```

## Deploy

1. Create the state store. Keep `infra/bootstrap/terraform.tfstate` safe, since it isn't stored remotely.

```bash
terraform -chdir=infra/bootstrap init
```

```bash
terraform -chdir=infra/bootstrap apply -var owner=your-name
```

2. Save the `backend_config` output as `infra/envs/lab/backend.hcl`.
3. Copy `infra/envs/lab/lab.tfvars.example` to `lab.tfvars` and fill it in.
4. Set your subscription, then review the plan and apply it. The VPN gateway alone can take 45 minutes.

```bash
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
```

```bash
terraform -chdir=infra/envs/lab init -backend-config=backend.hcl
```

```bash
terraform -chdir=infra/envs/lab plan -var-file=lab.tfvars -out=lab.tfplan
```

```bash
terraform -chdir=infra/envs/lab apply lab.tfplan
```

5. In Entra ID, open the **Azure VPN** enterprise application, require user assignment, and assign only the administrators. Otherwise any user in your tenant can connect through P2S.

## Everyday use

**Get a VM password.** Passwords are unique per VM. RDP over the P2S VPN to the private IP from the `vm_private_ips` output.

```bash
az keyvault secret show --vault-name <key_vault_name> --name vm-srv-aue-001-admin-password --query value -o tsv
```

**Turn the VPN off to save money.** This takes two applies, because Azure refuses to drop gateway transit while the other VNet still uses it:

```bash
terraform -chdir=infra/envs/lab apply -var-file=lab.tfvars -var vpn_transit_enabled=false
```

```bash
terraform -chdir=infra/envs/lab apply -var-file=lab.tfvars -var vpn_transit_enabled=false -var vpn_enabled=false
```

Turn it back on with a single normal apply using the default values. After that, download a new P2S client profile.

**Destroy everything.** This also deletes the backups, as intended for a lab. The state store has a delete lock and is not part of this.

```bash
terraform -chdir=infra/envs/lab destroy -var-file=lab.tfvars
```

**Allow a new internal flow.** Each NSG ends with a deny for VNet traffic. To add SQL on 1433, for example, add an allow rule to `azure_nsg_rules` in `envs/lab/locals.tf`.

## Run the checks

```bash
terraform -chdir=infra/envs/lab init -backend=false
```

```bash
terraform -chdir=infra/envs/lab test
```

```bash
tflint --config "$PWD/infra/.tflint.hcl" --init && tflint --config "$PWD/infra/.tflint.hcl" --chdir infra --recursive
```

```bash
checkov --config-file infra/.checkov.yaml --directory infra
```

## CI setup

`.github/workflows/terraform.yml` has never run. Before it can:

1. Create an Entra app with federated credentials for the GitHub environments `lab-plan` and `lab`. Give it Owner on the subscription, because plan and apply manage role assignments.
2. Pass its object ID to bootstrap, as `ci_principal_ids = { github = "<object-id>" }`, to grant state access.
3. Create both environments, restrict them to `main`, and add required reviewers to `lab`.
4. Add these repository variables: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `TFSTATE_RESOURCE_GROUP`, `TFSTATE_STORAGE_ACCOUNT`, `LAB_OWNER`, `LAB_ADMIN_USERNAME`, `LAB_ALERT_EMAIL`, `LAB_BUDGET_START_DATE`.

Pull requests only run checks and get no Azure token, so they show no real plan. Plans run on `main`, and an apply is a manual workflow run followed by approval.

## Accepted risks

These are the Checkov exceptions in `.checkov.yaml`, plus related decisions. None of them would be acceptable for real production.

| Decision | Why it's accepted here |
|---|---|
| B1 App Service plans, one instance (CKV_AZURE_211, 212, 225) and LRS storage (206) | Original requirement and cost |
| Public web app endpoints (222), no App Service auth or client certificates (13, 17) | Front Door Standard needs public origins. IP rules and the header check restrict them, and the apps have their own login. |
| Gallery storage reachable publicly with shared keys (35, 59) | The app runs in the browser and uses an account SAS. Account SAS lifetime is limited to 7 days. Moving to Entra ID sign-in needs a change in the third-party app. |
| State account reachable by Entra ID alone (35, 59) | Hosted CI runners have changing IPs. Use `allowed_ips` if you only deploy from fixed addresses. |
| Key Vault without a firewall (109, 189) | Same reason as the state account. Access needs Entra RBAC. |
| No secret expiry (41) | **Open gap:** rotation isn't implemented. |
| Encryption at host off (151) | Needs a subscription feature. Platform encryption stays on. |
| VM agent on (50), Azure Files content share unused (88), queue logging off (33) | Run Command needs the agent. The apps and accounts don't use the other two. |
| SCM site open to all networks | Deployment tools connect directly, and basic auth is off, so Entra ID is required. |
| Plain HTTP from Front Door to the IIS VMs | The VMs have no certificates yet. Traffic crosses the Microsoft network, but isn't encrypted. |
| Secrets in Terraform state | `azurerm` 5.12 has no write-only option for VM passwords or the VPN key. State has Entra-only access, versioning and a delete lock. |

## Not proven yet

- **Nothing has run on Azure.** Mock tests can't catch Azure rejecting a configuration, or quota and region limits.
- **The PowerShell has never run.** `pwsh` wasn't available, so the RRAS and IIS scripts need a first real test. RRAS on the same subnet as its client also needs a connectivity test.
- **File share backup with public access disabled** may need that setting relaxed to `Enabled` with a deny-by-default firewall, if vault registration fails.
- **Recovery Services soft delete** may delay `destroy` until retained items are purged.
- **Web apps have no internet egress.** They route everything through a private subnet with no NAT gateway. Add one if an app needs outbound calls.
- **The image version is `latest`.** Pin `image_version` for repeatable rebuilds.

## Left out on purpose

- **SQL Server:** the ticketing app needs it, but neither the scripts nor the diagram include it. Add a VM entry to `local.vms` and an NSG allow rule, or use Azure SQL.
- **External DNS and custom domains:** no domain was provided. Use the `*.azurefd.net` hostnames from `front_door_endpoints`.
- **DNS Private Resolver:** on-premises and P2S clients can't resolve the private file share name without it or a hosts file entry.
- **App code:** deploying and changing the third-party apps. Their published default credentials must be changed before any real use.
