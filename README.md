# Azure Landing Zone Lab

A small Azure environment declared in Terraform: hub-and-spoke networking, dev and prod, storage, compute,
identity and governance, monitoring. It is a learning project, built to get hands-on with Terraform on Azure
and to prepare for the **HashiCorp Terraform Associate** and **Microsoft AZ-104** exams.

A companion project, [terraform-kvm-lab](https://github.com/Marian421/terraform-kvm-lab), builds a similar
four-VM lab on a local KVM/libvirt host. That one taught the Terraform basics; this one applies them to Azure.

**Status:** work in progress. Done so far: provider setup, a remote-state backend, and hub-and-spoke networking
with NSGs, and two VMs built from one module: a jump host and a private VM in the dev spoke (phases 0 to 2 done,
phase 3 in progress).

## How it works so far

```
bootstrap/  (run once, local state)           main config  (this folder)
  resource group  tr-lab                        backend.tf  ->  state is stored in
  storage account trlabstate   <----------------------------   container "tfstate"
  container       tfstate                                      blob "landing-zone.tfstate"
```

- **`bootstrap/`** builds the place where Terraform will keep its state: a resource group, a storage account and a
  private container. It is its own Terraform root with a local state file, and it cannot live in the main config:
  `terraform init` needs the backend to exist before anything is built, and destroying the lab would otherwise
  delete the storage account holding its own state.
- **The main config** keeps its state in that container through the `azurerm` backend. Terraform takes a lease on
  the blob during a run, so two runs cannot overwrite each other's state.
- The storage account and container are protected with `lifecycle { prevent_destroy = true }`.
- The state account was first created by hand in the portal (to learn every option on the form), then adopted into
  Terraform with `import` blocks. The settings are reproduced in code, and a `plan` after the import showed
  only tag differences.

## Network design

```
                      vnet-hub 10.0.0.0/16
                      snet-shared 10.0.0.0/24  (nsg-shared: SSH from my current IP)
                     /                        \
        peering (both halves)              peering (both halves)
                   /                            \
   vnet-dev 10.1.0.0/16                  vnet-prod 10.2.0.0/16
   snet-web  10.1.0.0/24                 snet-web  10.2.0.0/24
   snet-data 10.1.1.0/24                 snet-data 10.2.1.0/24
   (nsg-dev: SSH from hub range)         (nsg-prod: SSH from hub range)
```

- **Hub and spokes.** Shared things go in the hub, workloads in a spoke each. Spokes only reach each other through the hub
  (peering is not transitive).
- **`modules/network`** builds one VNet plus its subnets. It is called once for the hub and once per spoke with `for_each`.
  Subnet ranges come from `cidrsubnet(address_space, 8, n)`, so a subnet is just a name and a number.
- **Spokes are data.** `locals.tf` holds a `spokes` map. Adding a spoke is one more entry: it gets a resource group,
  a VNet, two peerings and an NSG with no other change.
- **Peering** is created from both sides (`hub_to_spoke` and `spoke_to_hub`), each pointing at the other VNet by ID.
- **NSGs** are attached to subnets. The hub NSG allows SSH only from my current public IP, looked up with the `http`
  data source, so the rule follows my IP when it changes. Spoke NSGs allow SSH from the hub range. The association
  to every (spoke, subnet) pair uses `flatten()` to build a map for `for_each`.
- The address ranges never overlap, which peering requires.

## Reaching the VMs

```
laptop --SSH (key, from my current IP only)--> vm-jump  10.0.0.4  (hub, public IP)
                                                  |
                                       peering    |  SSH allowed from 10.0.0.0/16
                                                  v
                                             vm-dev-web  10.1.0.4  (dev spoke, no public IP)
```

- `modules/vm` builds a Linux VM, its NIC and, only when `public_ip = true`, a public IP (`count = var.public_ip ? 1 : 0`).
  It is called twice in `compute.tf`: `jump` (public IP, in the hub) and `dev-web` (private, in the dev spoke).
- The dev VM has no public address, so it can only be reached through the jump host:
  `ssh -J azureuser@<jump ip> azureuser@10.1.0.4`. `terraform output jump_ssh_command` prints the first hop.
- IP flow verify in Network Watcher confirms which NSG rule allows the hop (`allow-ssh-from-hub`).
- Terraform reads the public key from `var.ssh_public_key_path` in the root and passes the text to the module.

## Layout

| Path | Purpose |
|---|---|
| `versions.tf` | Terraform and `azurerm` provider pins (`~> 4.0`), provider block |
| `variables.tf` | Inputs: `subscription_id`, `location` |
| `locals.tf` | Common tags, hub address range, the `spokes` map |
| `main.tf` | Resource groups and the network module calls |
| `modules/network/` | Reusable VNet + subnets module (inputs, outputs `vnet_id`, `vnet_name`, `subnet_ids`) |
| `peering.tf` | Hub-to-spoke and spoke-to-hub peerings |
| `nsg.tf` | Network security groups and their subnet associations |
| `compute.tf` | The two VMs, as calls to `modules/vm` |
| `modules/vm/` | Reusable VM module (VM, NIC, optional public IP) |
| `outputs.tf` | Jump host public IP and a ready-to-paste SSH command |
| `backend.tf` | Remote state location (written out literally: backend blocks cannot use variables) |
| `bootstrap/` | One-off config that creates the state storage account |
| `terraform.tfvars` | Holds the subscription id. **Git-ignored** |

## Requirements

- Terraform >= 1.5
- Azure CLI, logged in with `az login` (the provider reuses that session, so no secrets are stored)
- An Azure subscription, with the resource providers `Microsoft.Storage`, `Microsoft.Compute` and `Microsoft.Network` registered

## Usage

```
# 1. once: create the state storage account
cd bootstrap
cp ../terraform.tfvars .        # or create terraform.tfvars with: subscription_id = "<your id>"
terraform init
terraform apply

# 2. the main config, which now stores its state in Azure
cd ..
terraform init
terraform plan
```

`terraform.tfvars` is not committed. Create it yourself with `subscription_id = "<your subscription id>"`.

## Decisions

- **Region:** `austriaeast`, picked by latency, with the same VM sizes as the nearest alternative.
- **Quota and VM size:** a new subscription starts with **4 vCPUs per region**. The 1-vCPU B sizes are not available on
  this subscription, so the VM size is `Standard_B2ats_v2` (2 vCPUs, 1 GiB). That allows **two VMs at once**: the jump host
  and one VM in dev. Prod is defined in code but not deployed. The quota counts the full size, even if the portal's
  "customize cores" cuts a VM to 1 vCPU (tested).
- **State account:** StorageV2, Standard performance, LRS, Hot tier, blob versioning and 7-day soft delete on,
  HTTPS only, TLS 1.2, anonymous access off, copy scope limited to the same Entra tenant. Account-key access is
  still on and will be replaced by Entra ID (RBAC) access in a later phase.
- **Cost:** a monthly budget with alerts, and a rule of destroying everything after each session apart from the state account.

## Things I ran into

- **Resource providers were not registered.** On a new subscription, `az vm list-sizes` failed with "entity not found"
  until `Microsoft.Compute` and friends were registered. The portal registers them silently; the CLI does not.
- **vCPU quota of 4.** Quotas are per VM family *and* per region in total, so `az vm list-usage -o table` is the way to check them.
- **An unquoted string in `terraform.tfvars`.** The subscription id needs quotes; without them Terraform stops
  with "Missing newline after argument".
- **`.gitignore` trap.** Ignoring `*.tfvars` but allowing `envs/*.tfvars` is right for per-environment files, but a
  subscription id put there would be committed. It lives in a top-level `terraform.tfvars` instead.
- **`lifecycle` is a block, not a map.** `lifecycle: {` fails validation; it is `lifecycle {`.
- **Name vs ID arguments.** `*_name` wants a name and `*_id` wants the full resource path. Passing a VNet name where
  an ID is expected fails with "parsing ... as a VirtualNetwork ID". A subnet association needs the subnet ID, not the VNet ID.
- **NSG default rules.** Rule 65000 `AllowVnetInBound` allows traffic between peered networks and between subnets of
  the same VNet on every port, so the SSH rule alone does not isolate tiers. A deny rule at a lower priority number is needed.
- **`ssh -J` does not use `-i` for the jump host.** The first hop failed with `Permission denied (publickey)` because the
  key is not one of SSH's default names. Fix: load it into an agent (`eval "$(ssh-agent -s)"; ssh-add <key>`), or use a
  `~/.ssh/config` entry, or an explicit `ProxyCommand`.
- **Moving resources into a module.** Putting existing resources into a module would have destroyed the VM. `moved` blocks
  rename them in state instead; after one clean apply they can be deleted.
- **My IP changes.** The hub NSG rule follows my public IP through the `http` data source, so a changed IP shows up as
  an in-place update on the next plan.
- **The portal does not delete a VM's public IP by default.** An orphaned public IP keeps billing; `az resource list -g <rg>`
  shows what is left.
- **Terraform stores secrets in state.** The plan shows `primary_access_key` as sensitive, but it is still in the state
  file in plain text, one reason to move to Entra ID authentication and turn key access off.

## Roadmap

| Phase | Topic | Status |
|---|---|---|
| 0 | Account, budget, provider setup | Done |
| 1 | Remote state in Azure Storage | Done |
| 2 | Hub-and-spoke networking: VNets, subnets, NSGs, peering | Done |
| 3 | Compute: Linux VMs, managed disks, load balancer | In progress (VMs and module done) |
| 4 | Identity and governance: RBAC, policy, locks, managed identity | |
| 5 | Monitoring, backup, storage extras | |
| 6 | Exam preparation | |

## Provider

[`hashicorp/azurerm`](https://registry.terraform.io/providers/hashicorp/azurerm) `~> 4.0`
and [`hashicorp/http`](https://registry.terraform.io/providers/hashicorp/http) `~> 3.0` (only to look up my public IP)
