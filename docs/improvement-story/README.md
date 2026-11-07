# Improvement story: from provided scripts to tested Terraform

This records how the project looked before and after, with the evidence, so you can turn it into a post, talk or portfolio piece.

**Status:** the Terraform passes static checks and mock-provider tests, but has **not** been applied to Azure. Don't describe it as deployed until it has been.

## Where the evidence lives

| File | What it shows |
|---|---|
| [Original state](#original-state) | The starting point, described below |
| [after-evidence.txt](after-evidence.txt) | Final tool output for the Terraform, including mutation checks |
| [../analysis-and-improvement-plan.md](../analysis-and-improvement-plan.md) | The findings and plan written before any Terraform existed |
| [../../infra/README.md](../../infra/README.md) | How to run it, accepted risks and open gaps |

## The short version

I started from a provided Bash script and an architecture diagram. The script didn't parse as delivered, built only the foundation of the diagram, and left its VMs unreachable or exposed. I replaced it with 7 Terraform modules covering the whole diagram, with tests that fail when a known defect comes back.

## Original state

- **Inputs:** a requirements list, one Azure CLI Bash script, a few setup notes and an architecture diagram, all in Portuguese.
- **Script:** created 2 resource groups, 3 VNets with 7 subnets, a peering, 2 NSGs with no rules, 2 App Service plans and 3 Windows VMs, through 20 `az ... create` commands.
- **Diagram, beyond the script:** a VPN gateway with S2S and P2S, Front Door, web apps, two storage accounts, a private endpoint with Private DNS, Azure Backup and a fourth VM.
- **Process:** everything else was configured by hand in the portal or over RDP.
- **Checks on the script:** `bash -n` failed with a syntax error. With line endings fixed, ShellCheck reported a misplaced shebang, an unquoted `read` and a stray backtick pair.

## Before and after

| Measure | Before | After |
|---|---|---|
| Runs as delivered | No: `bash -n` syntax error from CRLF line endings | `terraform validate` passes |
| Diagram coverage | Networks, NSGs, empty plans and 3 of 4 VMs | All of it, except external DNS (no domain provided) |
| Size | 20 `az ... create` commands | 132 planned resources in 7 modules |
| State and preview | None | Remote state and `terraform plan` |
| Automated tests | None | 11 test runs, plus 8 deliberate breaks all caught |
| Language | Portuguese | English |
| Passwords | Typed in per VM and passed as a command-line argument | Generated per VM and stored in Key Vault |
| Admin username | A person's name, hard-coded | A variable, with reserved names rejected |
| App setup | Manual over RDP | Run Command scripts with SHA-256 checks on downloads |
| Backup, monitoring, budgets | None | Regional vaults, Log Analytics, VPN alert, budgets, tag audit |
| CI | None | Lint, security scan and tests on every PR, with gated apply on `main` |

## The defects worth telling

These make the best material, because each one is invisible until you try to use the network.

1. **The script didn't run.** Windows line endings broke the function definition, and the shebang was on line 2.
2. **Hybrid routing could never work.** The peering had no gateway transit, so the Canada VNet couldn't reach on-premises, and the firewall VM had no IP forwarding.
3. **Security failed in both directions.** Two VMs had public IPs behind empty NSGs and rejected all inbound traffic. The third got a default NSG with RDP open to the internet.
4. **Requirements and script disagreed.** Standard SSD was requested but never set. Tags were requested on peerings, which Azure doesn't support.
5. **The diagram disagreed with the script.** It reused one VNet name twice and showed a gateway subnet with a name Azure wouldn't accept.
6. **One backup box was really three vaults.** Recovery Services vaults are regional and blob backup uses a different vault type, so one box in the diagram became three.

## What the build itself taught

The story is more credible with the mistakes in it. Passing the tools turned out not to be enough.

- **The first Checkov run** reported 48 failures. Some became real fixes, such as logging and health checks. The other 16 check types became exceptions, each with a written reason.
- **All checks passed, then two independent reviews found problems the tools couldn't:**
  - **Turning the VPN off would have failed.** Terraform would clear gateway transit before the other side released it, so this became a two-step process with its own test.
  - **Pull requests could have stolen secrets.** A PR could run its own code with an Azure token able to read state. PRs now get no token at all.
  - **My NSG allow-list was an illusion.** Azure's implicit `AllowVnetInBound` still opened every port to connected networks. Each NSG now ends in an explicit deny.
  - **The Front Door lockdown had a hole.** The IIS exemption for all of `10.0.0.0/8` let a compromised web app skip it. It now covers only loopback, on-premises and P2S clients.
  - **Download checks had a race.** A predictable temp path could let a file be swapped after hashing. Downloads now use a locked, randomly named folder.
- **One review suggestion was wrong.** It proposed `soft_delete_enabled`, which doesn't exist in the provider schema, so checking the schema first paid off.
- **I also caught my own bad evidence.** A "no exceptions" Checkov run looked perfect because it silently loaded the config file. Re-run on a clean copy, it reports the real count in `after-evidence.txt`.

## Honest limits

Include these if you publish this:

- **Never applied to Azure.** Mock tests prove the logic of the configuration, not that Azure accepts it. The first real `terraform apply` is the next chapter of the story.
- **The PowerShell has never run.** The RRAS and IIS scripts were reviewed, not executed.
- **Passing Checkov comes with 16 accepted exceptions.** They are listed with reasons in `infra/README.md`, and they include real trade-offs such as no secret rotation.
- **Not production-ready by design.** It uses single VMs, B1 plans, LRS storage and plain HTTP between Front Door and the VMs.
- **Left out:** SQL Server, custom domains, a DNS Private Resolver and changes to the applications, whose published default credentials must still be changed.

## Suggested next chapters

1. First `terraform apply`: record what Azure rejected and how long each part took.
2. Connectivity proof: `vm-clt-001` to both VNets, P2S to a private IP, and a direct-origin request refused.
3. Destroy and rebuild, then a backup restore test.
4. Real monthly cost compared with the budget.
