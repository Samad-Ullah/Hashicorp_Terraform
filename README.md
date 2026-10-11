# Terraform Associate (004) - Complete Study Guide

A complete, hands-on guide to **HashiCorp Terraform** and the **Terraform Associate (004)** exam.
It explains every exam topic with examples, commands and common traps.
Every concept was practised for real in the labs of this repository (Terraform 1.16.4), without cloud costs:
local providers, Vault and Consul in dev mode, and the HCP Terraform free tier.

> Exam facts from my study plan (check the official HashiCorp certification page before booking):
> 004 replaced 003 in January 2026, tracks Terraform 1.12, multiple choice, 60 minutes, valid 2 years.
> HCP Terraform is its own exam domain.

## Contents
1. [Infrastructure as Code (IaC)](#1-infrastructure-as-code-iac)
2. [Terraform fundamentals: providers and versions](#2-terraform-fundamentals-providers-and-versions)
3. [The core workflow and CLI](#3-the-core-workflow-and-cli)
4. [Configuration language](#4-configuration-language)
5. [Modules](#5-modules)
6. [State management](#6-state-management)
7. [Maintaining infrastructure](#7-maintaining-infrastructure)
8. [HCP Terraform](#8-hcp-terraform)
9. [Feature timeline (which version added what)](#9-feature-timeline)
10. [Exam traps](#10-exam-traps)
11. [The labs in this repository](#11-the-labs-in-this-repository)

---

## 1. Infrastructure as Code (IaC)

**IaC** = describing infrastructure (servers, networks, databases, DNS, permissions) in **code files**
instead of clicking in a web console.

**Advantages**
- **Repeatable**: the same code builds the same infrastructure every time (dev, staging, prod).
- **Versioned**: every change is in Git, with history, review (pull requests) and rollback.
- **Automatable**: CI/CD pipelines can plan and apply changes.
- **Self-documenting**: the code *is* the documentation of what exists.
- **Safer**: you see a **plan** of every change before it happens.
- **Fast recovery**: rebuild everything with one command.

**Terraform specifically**
- **Declarative**: you describe the **desired end state** ("3 servers"), not the steps. Terraform works out
  what to create, change or destroy.
- **Provider-based**: thousands of providers (AWS, Azure, GCP, Kubernetes, GitHub, Vault...) let one
  tool and one language (HCL) manage **multi-cloud, hybrid cloud and service-agnostic** workflows.
- **Stateful**: keeps a **state** record of what it created (section 6).
- **Idempotent**: applying the same code twice changes nothing the second time.

| Approach | Example | Style |
|---|---|---|
| Declarative IaC | Terraform, CloudFormation | "this is what I want" |
| Imperative scripts | bash + cloud CLI | "do this, then this" |
| Configuration management | Ansible, Chef, Puppet | configures software **inside** servers |

---

## 2. Terraform fundamentals: providers and versions

### Providers
A **provider** is a plugin that lets Terraform talk to one API (AWS, Azure, local files, random values...).
Terraform core does the planning; providers do the actual API calls.

- Providers come from the **Terraform Registry** (registry.terraform.io).
  Tiers: **Official** (HashiCorp), **Partner** (third-party companies), **Community** (individuals).
- Source address: `[HOSTNAME/]NAMESPACE/TYPE`, e.g. `hashicorp/aws` = `registry.terraform.io/hashicorp/aws`.
- `terraform init` downloads them into `.terraform/providers/`.

```hcl
terraform {
  required_version = ">= 1.12"            # Terraform CLI version

  required_providers {
    aws = {
      source  = "hashicorp/aws"           # always set source (otherwise hashicorp/<name> is assumed)
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

provider "aws" {                           # a second configuration of the same provider
  alias  = "us"
  region = "us-east-1"
}

resource "aws_s3_bucket" "logs" {
  provider = aws.us                        # use the aliased one
  bucket   = "my-logs"
}
```
- You can use **several different providers** in one configuration (e.g. aws + random + local).
- Without an explicit `provider` block, Terraform uses an empty default configuration.

### Version constraints
| Operator | Meaning | Example |
|---|---|---|
| `=` or none | exactly | `= 1.2.0` |
| `!=` | anything except | `!= 1.2.1` |
| `>`, `>=`, `<`, `<=` | comparisons | `>= 1.12` |
| `~>` | **only the rightmost number may increase** | `~> 3.6` = >= 3.6, < 4.0 ; `~> 3.6.0` = >= 3.6.0, < 3.7.0 |

Constraints can be combined: `">= 1.2, < 2.0"`. `required_version` should be the **real minimum** for the
features you use (e.g. `terraform_data` needs 1.4, write-only arguments need 1.11).

### Dependency lock file: `.terraform.lock.hcl`
- Created by `terraform init`. Records the **exact provider versions** chosen and their **checksums**.
- **Commit it to Git**, so everyone (and CI) uses the same provider versions.
- Plain `init` always respects it, even if a newer version fits the constraint.
  Only **`terraform init -upgrade`** picks newer versions.
- It tracks **providers only, not modules**.
- `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64` adds checksums for other OSes.
- `.terraform/` itself is a local cache: **never commit it**.
- Plugin cache (share downloads between projects): `TF_PLUGIN_CACHE_DIR` or `plugin_cache_dir` in the CLI config file.

---

## 3. The core workflow and CLI

**Write -> Plan -> Apply.**

```bash
terraform init        # download providers + modules, configure the backend
terraform fmt         # format code to the canonical style
terraform validate    # check syntax and internal consistency (needs init: provider schemas)
terraform plan        # show what would change (changes nothing)
terraform apply       # make the changes (asks for "yes")
terraform destroy     # delete everything this configuration manages
```

### Command reference
| Command | Notes |
|---|---|
| `init` | `-upgrade` (newer allowed provider/module versions, re-download modules), `-migrate-state`, `-reconfigure`, `-backend-config=FILE`, `-backend=false` |
| `fmt` | `-check` (exit code 3 if changes needed, for CI), `-diff`, `-recursive`. Formats `.tf` and `.tfvars`, never text inside strings |
| `validate` | needs providers installed; doesn't contact real APIs |
| `plan` | `-out=FILE` (save), `-var`, `-var-file`, `-destroy`, `-refresh-only`, `-refresh=false`, `-replace=ADDR`, `-target=ADDR` (exceptional use only), `-detailed-exitcode` (0 no changes, 1 error, 2 changes), `-generate-config-out=FILE` (with import blocks) |
| `apply` | `apply tfplan` applies a saved plan **without prompting**; `-auto-approve`; same flags as plan |
| `destroy` | = `apply -destroy`; still evaluates variables (required ones must be set) |
| `show` | whole state, or a saved plan (`show tfplan`); `-json` |
| `output` | all outputs (sensitive ones hidden); `output NAME`, `-raw`, `-json` **reveal sensitive values** |
| `console` | interactive expression testing (`upper(var.x)`, `cidrsubnet(...)`) |
| `graph` | dependency graph (DOT format) |
| `providers` | providers required by the configuration and modules |
| `version` | Terraform and provider versions |
| `get` | download modules only |
| `state list/show/mv/rm/pull/push` | inspect or edit state (section 7) |
| `import` | legacy CLI import (prefer `import` blocks) |
| `workspace new/select/list/show/delete` | CLI workspaces |
| `force-unlock LOCK_ID` | remove a stuck lock |
| `login` / `logout` | HCP Terraform token |
| `test` | run `.tftest.hcl` tests (1.6+) |

### Plan symbols
| Symbol | Meaning |
|---|---|
| `+` | create |
| `-` | destroy |
| `~` | update in place |
| `-/+` | destroy, then create a replacement (**default** for replacements) |
| `+/-` | create the replacement first, then destroy (`create_before_destroy`) |
| `<=` | read (data source) |

- Some arguments are **force-new** (`# forces replacement`): changing them replaces the resource.
- `(known after apply)` = a value only known once the resource exists (IDs, IPs).
- A saved plan becomes **stale** if the state changes before you apply it. Plan files can contain secrets.
- **`plan` never creates, changes or deletes anything.**

---

## 4. Configuration language

### Files and blocks
Terraform loads **all `.tf` files in a folder** together (order doesn't matter). Common layout:
`versions.tf`, `providers.tf`, `main.tf`, `variables.tf`, `outputs.tf`, `locals.tf`.

| Block | Purpose |
|---|---|
| `terraform {}` | required version, providers, backend / cloud |
| `provider` | configure a provider |
| `resource` | something Terraform **creates and owns** |
| `data` | something Terraform only **reads** |
| `variable` | an input |
| `output` | a value exposed after apply |
| `locals` | named internal values |
| `module` | call a module |
| `moved` / `removed` / `import` | refactoring and adoption (section 7) |
| `check` | health assertions (warnings) |
| `ephemeral` | values that are never stored (secrets) |

### Resources and data sources
```hcl
resource "aws_instance" "web" {          # address: aws_instance.web
  ami           = data.aws_ami.ubuntu.id  # reference = implicit dependency
  instance_type = "t3.micro"
}

data "aws_ami" "ubuntu" {                 # address: data.aws_ami.ubuntu
  most_recent = true
  owners      = ["099720109477"]
}
```
- Reference syntax: `TYPE.NAME.ATTRIBUTE`, `data.TYPE.NAME.ATTRIBUTE`, `var.NAME`, `local.NAME`, `module.NAME.OUTPUT`.
- Data sources are read **during plan** when all their inputs are known. If they depend on a resource with
  pending changes, they are read during apply.
- `terraform destroy` never deletes what a data source only reads.

### Variables
```hcl
variable "environment" {
  type        = string
  default     = "dev"                     # no default = required
  description = "Deployment environment."
  sensitive   = false
  nullable    = false
  ephemeral   = false                     # 1.10+: never stored in state or plan

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging or prod."
  }
}
```
**Ways to set a variable, lowest to highest precedence:**
1. `default` in the variable block
2. environment variable `TF_VAR_name`
3. `terraform.tfvars`
4. `terraform.tfvars.json`
5. `*.auto.tfvars` / `*.auto.tfvars.json` (alphabetical: `z.auto.tfvars` beats `a.auto.tfvars`)
6. `-var` and `-var-file` on the command line (**the last one wins**)

- A required variable with no value is **prompted** for (alphabetical order). With `-input=false` or in a
  remote HCP run, it's an error: `No value for required variable`.
- On the CLI, a primitive value is taken literally: `-var='replicas="5"'` is the text `"5"` with quotes (error for a number).
  In a `.tfvars` file, `"5"` is converted to the number 5.

### Locals and outputs
```hcl
locals {
  name_prefix = "${var.app}-${var.environment}"   # can't be overridden from outside
}

output "db_password" {
  value       = var.db_password
  description = "Database password."
  sensitive   = true                     # required if the value is sensitive
}
```

### Types
| Type | Example | Notes |
|---|---|---|
| `string`, `number`, `bool` | `"a"`, `5`, `true` | primitives |
| `list(T)` | `["a", "b", "a"]` | ordered, duplicates allowed, index `[0]` |
| `set(T)` | `toset(["b", "a", "b"])` -> `["a", "b"]` | unique, no index |
| `map(T)` | `{ dev = 1, prod = 3 }` | keys -> values of **one** type, iterated in **sorted** key order |
| `object({...})` | `{ engine = "pg", port = 5432 }` | named attributes of **different** types |
| `tuple([...])` | `["sun", 3]` | fixed positions with fixed types |
| `any` | | let Terraform infer |

`optional(type, default)` inside an object (1.3+): `port = optional(number, 5432)`.
A `{ ... }` literal in `locals` is an **object**, not a map, unless converted (`tomap()` or a map-typed variable).

### Expressions
```hcl
# conditional
log_level = var.environment == "prod" ? "warn" : "debug"

# for expressions
upper_names = [for s in var.services : upper(s.name)]                    # list
by_name     = { for s in var.services : s.name => s }                    # map
public      = [for s in var.services : s.name if s.public]               # filter
by_team     = { for s in var.services : s.team => s.name... }            # group duplicates with ...

# splat (lists, sets, tuples only - not maps)
names = var.services[*].name
ports = values(var.service_map)[*].port

# string templates
greeting = "Hello, ${var.name}!"
config   = <<-EOT
  APP=${var.app}
  %{ for s in var.services ~}
  SERVICE=${s}
  %{ endfor ~}
EOT
rendered = templatefile("${path.module}/nginx.conf.tftpl", { port = 8080 })
```
- `~` in `%{ ... ~}` strips the whitespace/newline next to a template directive.
- `path.module` = this module's folder, `path.root` = the root module's folder, `path.cwd` = current directory.

**Dynamic blocks** generate repeated nested blocks:
```hcl
dynamic "ingress" {
  for_each = var.ports                    # iterator is named after the block: ingress.value
  content {
    from_port = ingress.value
    to_port   = ingress.value
    protocol  = "tcp"
  }
}
```
Use `iterator = port` to rename it. Don't overuse dynamic blocks: they hurt readability.

### Functions (the ones the exam likes)
| Group | Functions |
|---|---|
| Strings | `upper`, `lower`, `format("%s-%03d", "web", 7)` -> `"web-007"`, `join(", ", list)`, `split`, `replace`, `trimspace`, `strcontains`, `regex`, `substr` |
| Collections | `length`, `concat`, `merge` (later wins), `flatten`, `distinct`, `sort`, `keys`, `values`, `lookup(map, key, default)`, `contains`, `element(list, i)` (**wraps around**), `index`, `zipmap`, `toset`, `tomap`, `tolist`, `coalesce` (first non-empty) |
| Errors | `try(expr, fallback)` (catches any error), `can(expr)` (true/false, used in validations) |
| Encoding | `jsonencode`, `jsondecode`, `yamlencode`, `base64encode` |
| Files | `file`, `templatefile`, `fileexists` |
| Network | `cidrsubnet("10.0.0.0/16", 8, 2)` -> `"10.0.2.0/24"`, `cidrhost` |
| Numbers | `min`, `max`, `abs`, `ceil`, `floor` |
| Other | `timestamp`, `uuid`, `sensitive()`, `nonsensitive()`, `issensitive()` |

`["a","b","c"][4]` is an error (`Invalid index`), but `element(["a","b","c"], 4)` returns `"b"`.

### Meta-arguments
| Meta-argument | Purpose |
|---|---|
| `count` | N copies, addressed by **index**: `aws_instance.web[0]`, `count.index` |
| `for_each` | one copy per **key** of a map/set: `aws_instance.web["api"]`, `each.key`, `each.value` |
| `depends_on` | explicit dependency when there's no reference |
| `provider` | choose an aliased provider |
| `lifecycle` | replacement and protection rules |

- `count` and `for_each` can't be used together (`Invalid combination of "count" and "for_each"`).
- **Index-shift trap**: removing a middle item from a `count` list changes the index of every later item, so
  Terraform replaces or destroys resources you didn't touch. `for_each` only affects the removed key.
- `for_each` keys must be **known at plan time** (`Invalid for_each argument` if they come from values
  only known after apply).

### Dependencies
- **Implicit**: a reference (`aws_instance.web.id`) makes Terraform build the referenced object first.
  Preferred.
- **Explicit**: `depends_on = [aws_iam_role_policy.x]` only when the dependency is hidden (e.g. a data source
  reading a file by its path string). Overuse slows applies and hides intent.
- Independent resources are created **in parallel**.

### Lifecycle
```hcl
lifecycle {
  create_before_destroy = true                     # +/- : no downtime on replacement
  prevent_destroy       = true                     # any plan that destroys it fails: "Instance cannot be destroyed"
  ignore_changes        = [tags]                   # ignore differences in these attributes after creation
  replace_triggered_by  = [terraform_data.version] # replace when that object changes
}
```
`prevent_destroy` can't use variables. `ignore_changes` doesn't stop Terraform recreating a resource that disappeared.

### terraform_data and provisioners
- `terraform_data` (1.4+, replaces `null_resource`): a built-in resource that stores a value (`input` -> `output`),
  useful for `replace_triggered_by` and provisioners. `triggers_replace` forces replacement.
- Provisioners (`local-exec`, `remote-exec`, `file`) run commands at **create** (default) or **destroy** (`when = destroy`).
  They are a **last resort**: not declarative, not in the plan, not tracked in state.
  - They run only on create/destroy, never on a no-change apply. `-replace` runs destroy-time, then create-time.
  - A failed create-time provisioner marks the resource **tainted** (replaced next apply). `on_failure = continue` changes that.
  - Destroy-time provisioners can only reference `self`.

### Custom conditions (validation)
| Tool | Where | When | On failure |
|---|---|---|---|
| `validation` | `variable` block | first, before planning | **error**: `Invalid value for variable` |
| `precondition` | `lifecycle` of resource/data, or `output` | before the object is planned | **error**: `Resource precondition failed` |
| `postcondition` | `lifecycle`, can use `self` | as soon as the result is known (can be at **plan** time) | **error**: `Resource postcondition failed` |
| `check` block | top level, with an optional scoped data source | end of every plan/apply | **warning only**: apply completes |

- A variable can have several `validation` blocks; all of them are reported.
- Validations can reference other variables (1.9+).
- Preconditions can check anything (other resources, data sources); validations only see variables.

### Sensitive data
| Level | Hidden in CLI | Stored in state/plan | Since |
|---|---|---|---|
| `sensitive = true` | yes | **yes, plain text** | 0.14 |
| `ephemeral` variables/resources | yes | **never** | 1.10 |
| write-only arguments (`*_wo`) | yes | **never** (only a `*_wo_version` number) | 1.11 |

- Sensitivity spreads: a value built from a sensitive value is sensitive.
- Ephemeral values can only go into provider configs, write-only arguments, locals, other ephemeral
  resources and provisioners. Not into normal arguments (`Invalid use of ephemeral value`), not into root outputs.
- Write-only values are re-sent only when you bump the `_version`: that's how you rotate a secret.
- **Protect state**: remote backend with encryption and access control, never commit it, clean old backups and versions.

### HashiCorp Vault
- A secrets manager: KV secrets (versioned in KV v2), **dynamic secrets** (short-lived credentials generated on demand).
- The Vault provider authenticates with `VAULT_ADDR` / `VAULT_TOKEN` env vars or a machine auth method
  (AppRole, JWT/OIDC in CI). **Never put tokens in code.**
- `data "vault_kv_secret_v2"` copies the whole secret into state (deprecated in recent providers).
  `ephemeral "vault_kv_secret_v2"` reads it without storing it.
- Dev mode (`vault server -dev`) is in-memory, auto-unsealed, plain HTTP: learning only, never production.

---

## 5. Modules

**Every folder of `.tf` files is a module.** The folder where you run Terraform is the **root module**;
modules it calls are **child modules**.

```hcl
module "web" {
  source  = "terraform-aws-modules/vpc/aws"   # where the code is
  version = "~> 5.0"                          # registry sources only

  name = "shopcart"                           # inputs = the child's variables
  cidr = "10.0.0.0/16"
}

output "vpc_id" {
  value = module.web.vpc_id                   # outputs = the only way out
}
```

**Scope**
- The child only sees the inputs you pass (its `variable` blocks). It can't see the root's variables.
- The root only sees the child's `output` values: `module.NAME.OUTPUT`.
- Providers are **inherited** by child modules. A child declares `required_providers` but should not contain
  `provider` blocks. Pass aliased providers with `providers = { aws = aws.us }`.
- Resources inside a module have addresses like `module.web.aws_instance.this`.
- `module` blocks support `count`, `for_each`, `depends_on` and `providers`.
- Validation inside the module protects every caller.

**Sources**
| Source | Example | `version`? |
|---|---|---|
| Local path | `"./modules/vpc"`, `"../modules/vpc"` | no |
| Public Registry | `"NAMESPACE/NAME/PROVIDER"` | **yes** |
| Private registry | `"app.terraform.io/ORG/NAME/PROVIDER"` | yes |
| GitHub | `"github.com/org/repo//modules/vpc?ref=v1.2.0"` | no, use `?ref=` |
| Generic Git | `"git::https://example.com/repo.git//modules/vpc?ref=v1.2.0"` | no, use `?ref=` |
| S3 / GCS / HTTP | `"s3::https://..."`, `"gcs::https://..."` | no |

- `//` separates the repository from the subfolder. `?ref=` pins a tag, branch or commit.
- A git source **clones the whole repository**. One module per repo (or a registry) keeps downloads small.
- `init` downloads modules into `.terraform/modules/`. A new or changed module block needs `init`.
  Stale module cache: `terraform init -upgrade` or delete `.terraform/modules`.
- **Semantic versioning**: MAJOR (breaking, e.g. renamed input), MINOR (compatible feature), PATCH (fix).
  Pin versions so each caller upgrades when ready. A breaking change shows up as `Unsupported argument` /
  `Missing required argument` at init/plan.
- Standard layout: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `README.md`. Good descriptions are the module's documentation.

---

## 6. State management

### What state is
`terraform.tfstate` (JSON) is Terraform's record of what it manages. It's used for:
1. **Mapping** code addresses to real objects (IDs).
2. **Metadata**: dependencies, so deletion order is known even after code is removed.
3. **Performance**: cached attribute values.
4. **Collaboration**: shared remote state with locking.

Before each plan Terraform **refreshes** (reads real values) and compares **code vs state vs reality**.

| Field | Meaning |
|---|---|
| `version` | state file format version |
| `terraform_version` | Terraform that last wrote it |
| `serial` | +1 on every write |
| `lineage` | unique ID from creation, never changes |
| `resources` | objects; `for_each` instances have `index_key` |

`serial` and `lineage` protect against overwriting newer state with older or unrelated state.
**Never edit state by hand.** State contains **secrets in plain text**.

### Backends
The backend decides where state is stored and whether locking works.
- Default: **`local`** (`terraform.tfstate` in the folder, plus `terraform.tfstate.backup`).
- Remote: `s3` (locking with `use_lockfile = true`, 1.10+; DynamoDB locking is deprecated), `azurerm`, `gcs`,
  `consul`, `pg`, `kubernetes`, `http`, HCP Terraform (`cloud` block).

```hcl
terraform {
  backend "s3" {
    key          = "shopcart/dev/terraform.tfstate"
    use_lockfile = true
  }
}
```
```bash
terraform init -backend-config=dev.s3.hcl     # partial configuration: bucket, region, credentials
```
- **Backend blocks can't use variables** (`Variables not allowed`): use partial configuration.
- Changing the backend requires `init`: `-migrate-state` copies the state, `-reconfigure` starts fresh.
  Migration never touches real infrastructure. Delete stale local copies afterwards.
- `-backend-config` values are saved in `.terraform/terraform.tfstate`.

### Locking
- Automatic for every operation that can write state. A second operation fails with
  `Error acquiring the state lock` (local backend: a `.terraform.tfstate.lock.info` file shows who, what, when, ID).
- `-lock-timeout=60s` waits instead of failing. `terraform force-unlock LOCK_ID` removes a **stuck** lock.
  `-lock=false` is dangerous.

### Reading another configuration's state
```hcl
data "terraform_remote_state" "network" {
  backend = "s3"
  config  = { bucket = "...", key = "network/terraform.tfstate", region = "eu-west-1" }
}
# data.terraform_remote_state.network.outputs.vpc_id
```
Only **root outputs** are exposed, but the reader needs access to the **whole** state (secrets included).
Safer: publish values to a parameter store, or use `tfe_outputs` in HCP Terraform.

---

## 7. Maintaining infrastructure

### Inspecting and editing state
| Command | Use |
|---|---|
| `terraform state list` | all addresses (quote brackets in bash: `'aws_instance.web["api"]'`) |
| `terraform state show ADDR` | one resource |
| `terraform show` | everything (or a plan file); `-json` |
| `terraform state mv OLD NEW` | rename an address (instant, not in a plan) |
| `terraform state rm ADDR` | forget a resource without destroying it |
| `terraform state pull` / `push` | download / upload raw state (push is dangerous) |

### Refactoring with blocks (preferred: shown in the plan, reviewed in Git)
```hcl
moved {                                  # 1.1+: rename without destroy (also into/out of modules, add count)
  from = aws_instance.db
  to   = aws_instance.database
}

removed {                                # 1.7+: stop managing without destroying
  from = aws_instance.legacy
  lifecycle {
    destroy = false
  }
}

import {                                 # 1.5+: adopt an existing object (for_each supported in 1.7+)
  to = aws_s3_bucket.assets
  id = "shopcart-assets"                 # ID format: provider docs, Import section
}
```
- Renaming without `moved` = destroy + create (data loss on a database).
- Keep `moved` blocks until every state using the code has applied them (forever in shared modules).
- `state rm` / `removed` while the resource is still in code -> Terraform will try to **create** it again.
- `terraform plan -generate-config-out=generated.tf` writes the resource block for import blocks. Review it.
  `plan` reads; only `apply` records the import (`1 imported`).
- Legacy `terraform import ADDR ID` writes state immediately and needs the resource block first.
- Not every resource type supports import.

### Replacing and tainting
- `terraform apply -replace=ADDR` forces a replacement (replaces the deprecated `terraform taint`).

### Drift
Drift = reality changed outside Terraform (console, CLI, scripts).
| Command | Effect |
|---|---|
| `terraform plan` | refresh, then plan to put things back as the **code** says |
| `terraform plan -refresh-only` | show what changed outside (`Objects have changed outside of Terraform`), propose nothing |
| `terraform apply -refresh-only` | accept the changes into **state** only (replaces deprecated `terraform refresh`) |
The next normal apply still reverts to the code. To keep a manual change, **change the code**.

### CLI workspaces
```bash
terraform workspace new staging | select default | list | show | delete staging
```
- Several **states** for the same configuration; `terraform.workspace` holds the current name.
- Stored per backend (local: `terraform.tfstate.d/NAME/`; others use a name suffix).
- A new workspace starts empty. You can't delete the current workspace or a non-empty one
  (`-force` leaves orphans): destroy first.
- Same credentials and backend for all workspaces. For real environments, prefer separate directories
  with shared modules. **Not** the same as HCP Terraform workspaces.

### Logging
| Variable | Meaning |
|---|---|
| `TF_LOG` | `TRACE` > `DEBUG` > `INFO` > `WARN` > `ERROR` (`JSON` = TRACE as JSON) |
| `TF_LOG_PATH` | write to a file (default: stderr) |
| `TF_LOG_CORE` / `TF_LOG_PROVIDER` | log only core or only providers |
A crash writes `crash.log`. Logs can contain secrets.

---

## 8. HCP Terraform

HashiCorp's hosted service (formerly Terraform Cloud) for running Terraform as a team.
**Terraform Enterprise** is the self-hosted version.

| Concept | Meaning |
|---|---|
| Organization | top level: billing, SSO, policies, variable sets, teams |
| Project | groups workspaces; team permissions and defaults apply to all of them |
| Workspace | one configuration + its own state, variables, runs and permissions |
| Run | a plan (+ apply), queued one at a time per workspace |

### Connecting: the `cloud` block
```hcl
terraform {
  cloud {
    organization = "my-org"              # or env var TF_CLOUD_ORGANIZATION
    workspaces {
      name = "shopcart-dev"              # created on first init; or tags = ["shopcart"]
    }
  }
}
```
- `terraform login` saves a user token in `~/.terraform.d/credentials.tfrc.json`.
  CI uses the env var `TF_TOKEN_app_terraform_io`. Tokens: user, team, organization.
- The `cloud` block (1.1+) replaces `backend "remote"`. No variables allowed in it.
- No local state file: state is versioned, encrypted and locked in HCP.
- `init` on a config with local state asks to **migrate** it (yes = copy, no = start empty).

### Workflows
| Workflow | How runs start |
|---|---|
| CLI-driven | `terraform plan/apply` on your machine, executed remotely, output streamed |
| VCS-driven | push / pull request on GitHub, GitLab, Bitbucket or Azure DevOps |
| API-driven | CI pipelines and scripts through the API |
- VCS: a pull request gets a **speculative plan** (never applied, shown on the PR). A push to the tracked branch gets a real run.
  CLI `apply` is not allowed on VCS-connected workspaces. Set a **working directory** for repos with many folders.

### Execution modes
| Mode | Where it runs | Workspace variables |
|---|---|---|
| Remote (default) | HCP's servers | used |
| Local | your machine (HCP only stores state) | **ignored** |
| Agent | agents inside your own network | used |

### Variables
- Categories: **Terraform variables** (fill `variable` blocks) and **environment variables** (provider credentials, `TF_LOG`).
- Sensitive variables are write-only (never readable again).
- **Variable sets** share variables across workspaces, projects or the whole org; a workspace value wins over a set.
- Remote runs can't prompt: a missing variable is an error.

### Collaboration and governance
| Feature | Purpose |
|---|---|
| Teams and permissions | e.g. plan vs apply rights per workspace/project |
| Run approval / auto-apply | manual "Confirm & apply" or automatic |
| Notifications | Slack, Teams, email, webhooks |
| Run triggers | an apply in workspace A queues a run in workspace B |
| Private registry | share modules/providers inside the org |
| No-code modules | create infrastructure from an approved module via a form |
| Policy as code | **Sentinel** (advisory / soft-mandatory / hard-mandatory) or **OPA** (advisory / mandatory), in policy sets, checked after plan and before apply |
| Run tasks | external checks (security, cost) at run stages |
| Health assessments | **drift detection** (background refresh-only plans) and **continuous validation** (checks and conditions) |

Feature availability per paid tier changes over time: check HashiCorp's pricing page.

---

## 9. Feature timeline

| Version | Added |
|---|---|
| 0.13 | `count` / `for_each` / `depends_on` on modules |
| 0.14 | sensitive variables, dependency lock file |
| 0.15 | sensitive outputs enforced; `-replace` |
| 1.1 | `moved` blocks, `cloud` block |
| 1.2 | preconditions / postconditions, `replace_triggered_by` |
| 1.3 | `optional()` object attributes with defaults |
| 1.4 | `terraform_data` |
| 1.5 | `import` blocks, `-generate-config-out`, `check` blocks |
| 1.6 | `terraform test` |
| 1.7 | `removed` blocks, `import` with `for_each` |
| 1.9 | validations referencing other variables |
| 1.10 | ephemeral values and resources; S3 native locking (`use_lockfile`) |
| 1.11 | write-only arguments |

---

## 10. Exam traps

1. `validate` needs `init` (provider schemas); `fmt` doesn't.
2. `~> 3.6` allows 3.x; `~> 3.6.0` allows 3.6.x only.
3. Commit `.terraform.lock.hcl`, never `.terraform/`. The lock file tracks providers, not modules.
4. `plan` changes nothing. A saved plan applies without a prompt and fails if stale.
5. Variable precedence: default < `TF_VAR_` < `terraform.tfvars` < `.tfvars.json` < `*.auto.tfvars` < `-var`/`-var-file` (last wins).
6. `sensitive` hides output only; the value is still in state. `output NAME` / `-json` / `-raw` reveal it.
7. Ephemeral and write-only values never reach state; ephemeral can't go into normal arguments or root outputs.
8. `check` blocks give **warnings**; validation/pre/postconditions give **errors**.
9. `count` index shift vs `for_each` keys; `for_each` keys must be known at plan time; never both together.
10. Default replacement is destroy-then-create (`-/+`); `create_before_destroy` gives `+/-`.
11. Provisioners are a last resort; failed create-time provisioner = tainted.
12. Every folder is a module; children see only inputs, roots see only outputs; providers are inherited.
13. `version` only works for registry module sources; git uses `?ref=`.
14. Backend and `cloud` blocks can't use variables; use partial configuration / env vars.
15. `-migrate-state` copies state, `-reconfigure` doesn't; migration never changes infrastructure.
16. Locking is automatic; `force-unlock` only for stuck locks.
17. Renaming or moving into a module without `moved` = destroy + create.
18. `moved` / `removed` / `import` blocks appear in plans; `state mv` / `state rm` / `terraform import` don't.
19. `state rm` on a resource still in code -> it will be created again.
20. `plan -refresh-only` shows drift; `apply -refresh-only` records it; the code wins on the next apply.
21. `terraform refresh` and `taint` are deprecated: use `-refresh-only` and `-replace`.
22. CLI workspaces ≠ HCP Terraform workspaces.
23. `TF_LOG` levels TRACE/DEBUG/INFO/WARN/ERROR; `TF_LOG_PATH` for a file.
24. HCP: remote runs can't prompt; local mode ignores workspace variables; PRs get speculative plans; no CLI apply on VCS workspaces.
25. Sentinel levels: advisory, soft-mandatory (overridable), hard-mandatory. Policies run after plan, before apply.
26. HCP Terraform = SaaS; Terraform Enterprise = self-hosted.

---

## 11. The labs in this repository

Each lab has a `NOTES.md` with the real commands, outputs and errors from doing it.

| Folder | Topic | Exam objectives |
| --- | --- | --- |
| [`01Basics`](01Basics) | First configuration: `local` provider, `local_file`, output | 1, 3 |
| [`02-core-workflow`](02-core-workflow/NOTES.md) | Workflow, version constraints, lock file | 2a-2c, 3 |
| [`03-variables-and-types`](03-variables-and-types/NOTES.md) | Variable precedence, types, sensitive in state | 4c, 4d |
| [`04-expressions-and-functions`](04-expressions-and-functions/NOTES.md) | `for`, splat, templates, dynamic blocks, functions | 4e |
| [`05-resources-and-meta-arguments`](05-resources-and-meta-arguments/NOTES.md) | count vs for_each, depends_on, lifecycle, remote state, provisioners | 4a, 4b, 4f, 2c |
| [`06-validation-and-secrets`](06-validation-and-secrets/NOTES.md) | Conditions, check blocks, ephemeral, write-only, Vault | 4g, 4h |
| [`07-state-management`](07-state-management/NOTES.md) | Backends, locking, Consul, moved/removed/import, drift, workspaces, TF_LOG | 2d, 6, 7 |
| [`08-modules`](08-modules/NOTES.md) | Own module, git-tagged v1/v2, Registry module, refactor with moved | 5a-5d |
| [`09-hcp-terraform`](09-hcp-terraform/NOTES.md) | cloud block, variables, execution modes, migration, VCS runs | 8a-8d |

### Running a lab
```bash
cd <lab folder>
terraform init
terraform plan
terraform apply
terraform destroy
```
- Labs 05 (`producer/`, `app/`) and 08 (`app/`, `payments/`) contain several root modules: run Terraform inside them.
- Lab 06 needs a Vault dev server, lab 07 a Consul dev agent, lab 09 an HCP Terraform account (`terraform login`).
- `.terraform/`, `*.tfstate`, `*.tfvars` and saved plans are not committed (caches and secrets).
  `.terraform.lock.hcl` **is** committed so provider versions stay reproducible.

### Roadmap
1. Terraform Associate (004): this repository.
2. Cloud capstone on free credits: real resources, S3 remote state, own modules for dev/staging/prod, CI, tests, drift detection.
3. Next: AWS Solutions Architect Associate, then Terraform Authoring and Operations Professional.
