# Hashicorp_Terraform

Hands-on practice repository for the **HashiCorp Terraform Associate (004)** exam.
Every lab was built step by step and run for real (Terraform 1.16.4), with no cloud costs:
local providers, Vault and Consul in dev mode, and the HCP Terraform free tier.
Each lab has a `NOTES.md` with the real commands, outputs, errors and exam traps.

## Labs

| Folder | Topic | Exam objectives | Highlights |
| --- | --- | --- | --- |
| [`01Basics`](01Basics) | First configuration | 1, 3 | `local` provider, one `local_file`, one output |
| [`02-core-workflow`](02-core-workflow/NOTES.md) | Core workflow, providers | 2a-2c, 3 | `init`/`fmt`/`validate`/`plan -out`/`apply`/`destroy`, version constraints, lock file |
| [`03-variables-and-types`](03-variables-and-types/NOTES.md) | Variables, outputs, types | 4c, 4d | precedence battle, list/set/map/object/tuple, `optional()`, sensitive in state |
| [`04-expressions-and-functions`](04-expressions-and-functions/NOTES.md) | Expressions and functions | 4e | `for`, splat, conditionals, grouping `...`, `templatefile`, `dynamic` blocks, console |
| [`05-resources-and-meta-arguments`](05-resources-and-meta-arguments/NOTES.md) | Resources, data sources, meta-arguments | 4a, 4b, 4f, 2c | `count` vs `for_each` index shift, `depends_on`, `lifecycle`, `terraform_remote_state`, provisioners |
| [`06-validation-and-secrets`](06-validation-and-secrets/NOTES.md) | Validation and secrets | 4g, 4h | validation, pre/postconditions, `check` blocks, ephemeral, write-only, Vault |
| [`07-state-management`](07-state-management/NOTES.md) | State | 2d, 6, 7 | backends, locking, Consul remote state, `moved`/`removed`/`import`, drift, workspaces, `TF_LOG` |
| [`08-modules`](08-modules/NOTES.md) | Modules | 5a-5d | own module, git-tagged v1/v2 with a breaking change, Registry module, refactor with `moved` |
| [`09-hcp-terraform`](09-hcp-terraform/NOTES.md) | HCP Terraform | 8a-8d | `cloud` block, variables and variable sets, execution modes, state migration, VCS-driven runs |

## Usage

```bash
cd <lab folder>
terraform init
terraform plan
terraform apply
terraform destroy
```
Labs 05 (`producer/`, `app/`) and 08 (`app/`, `payments/`) have several root modules: run Terraform inside those subfolders.
Lab 06 needs a Vault dev server, lab 07 a Consul dev agent, lab 09 an HCP Terraform account (`terraform login`).

`.terraform/`, `*.tfstate`, `*.tfvars` and saved plans are intentionally not committed: provider binaries are
re-downloaded by `terraform init`, and state, tfvars and plans can contain secrets in plain text.
`.terraform.lock.hcl` **is** committed on purpose, so provider versions stay reproducible.

---

# Exam cheat sheet

## 1-3. IaC, fundamentals, core workflow
- **IaC**: infrastructure described in code -> versioned, reviewed, repeatable. Terraform is declarative and provider-based (multi-cloud).
- Workflow: **Write -> Plan -> Apply**. `init` (providers, modules, backend) -> `fmt` -> `validate` -> `plan` -> `apply` -> `destroy`.
- `validate` needs providers installed (`init` first). `fmt` doesn't. `fmt` also formats `.tfvars`, never text inside strings.
- `plan -out=tfplan` + `apply tfplan` = no prompt. A saved plan becomes **stale** if state changes. Plan files can hold secrets.
- Version constraints: `~> 3.6` = >= 3.6, < 4.0. `~> 3.6.0` = >= 3.6.0, < 3.7.0.
- `.terraform.lock.hcl`: commit it. `init` respects it; only `init -upgrade` picks newer versions.
- Plan symbols: `+` create, `-` destroy, `~` update in place, `-/+` destroy then create (default), `+/-` create then destroy (`create_before_destroy`).
- Provider aliases: `provider "aws" { alias = "west" }` + `provider = aws.west`.

## 4. Configuration
- **Variable precedence** (low -> high): default -> `TF_VAR_` -> `terraform.tfvars` -> `terraform.tfvars.json` -> `*.auto.tfvars` (alphabetical) -> `-var`/`-var-file` (last wins).
- Missing required variable: prompted in **alphabetical** order (locally). Remote runs (HCP) fail instead.
- Types: list (ordered), set (unique, unordered), map (same value type), object (named attributes), tuple (typed positions). `optional(type, default)`.
- `{ ... }` in locals = object. Map keys always iterate **sorted**.
- `for`: `[for x in y : ...]` = list, `{for k, v in y : k => v}` = map, `...` groups duplicate keys. Splat `[*]` only on lists/sets.
- `try()` catches any error, `can()` returns true/false, `lookup()` only handles a missing map key. `element()` wraps around.
- **Resource** = Terraform creates and owns it. **Data source** = read only (read during plan when inputs are known).
- `count` = by index (removing a middle item shifts and rebuilds the rest). `for_each` = by key (only that key changes). Keys must be known at plan time.
- `depends_on` only for hidden dependencies (no reference in code).
- `lifecycle`: `create_before_destroy`, `prevent_destroy` (`Instance cannot be destroyed`), `ignore_changes`, `replace_triggered_by`.
- Provisioners = last resort. A failed create-time provisioner -> resource **tainted**. Destroy-time ones can only use `self`.
- **Custom conditions**: `validation` (inputs, first), `precondition` (before), `postcondition` (after, `self`, can fail at plan), `check` blocks (**warnings only**).
- `sensitive` hides values in CLI output **only**: still plain text in state. `terraform output NAME`, `-raw` and `-json` reveal it.
- `ephemeral` (1.10+) and write-only `_wo` arguments (1.11+) **never** reach state. Rotate write-only values by bumping `_version`.
- Vault: auth via `VAULT_ADDR`/`VAULT_TOKEN` env vars, never in code. Data source = secret copied into state; ephemeral resource = not stored. Dev mode = in-memory, never production.

## 5. Modules
- Every folder is a module. Root = where you run Terraform. Never run Terraform inside a child module folder.
- Child sees only its inputs (`variable`). Root sees only outputs (`module.NAME.OUTPUT`). Providers are inherited (no `provider` block in a child).
- Sources: local `./`/`../`, Registry `NAMESPACE/NAME/PROVIDER` (+ `version`), private `app.terraform.io/ORG/NAME/PROVIDER`,
  git `git::https://...//subdir?ref=TAG` (no `version`), GitHub, S3, GCS, HTTP.
- New/changed source -> `terraform init`. `init -upgrade` = newest allowed version + re-download (fixes stale caches).
- SemVer: MAJOR = breaking (callers must change code). Pin versions so callers upgrade when they choose.
- Renaming a module call or moving resources into a module changes addresses -> `moved` block.

## 6-7. State and maintenance
- State = mapping, metadata, performance, collaboration. `serial` +1 per write, `lineage` never changes.
- Backend blocks can't use variables -> partial config `-backend-config=file`. `-migrate-state` copies, `-reconfigure` doesn't.
- Locking is automatic. `-lock-timeout=60s` waits. `force-unlock ID` only for stuck locks. `-lock=false` is dangerous.
- `moved` (rename), `removed` + `destroy = false` (forget), `import` + `-generate-config-out` (adopt) blocks show in plan.
  `state mv` / `state rm` / `terraform import` CLI commands don't.
- `state rm` while still in code -> Terraform tries to **create** it again.
- Import ID format: provider docs (Import section). Value: the real object.
- Drift: `plan -refresh-only` shows it, `apply -refresh-only` writes it to state, the next normal apply puts the code back.
- CLI workspaces: separate states for the same code (`terraform.workspace`). Can't delete a non-empty or current workspace. Not the same as HCP workspaces.
- `TF_LOG` = TRACE > DEBUG > INFO > WARN > ERROR (JSON), `TF_LOG_PATH`, `TF_LOG_CORE`, `TF_LOG_PROVIDER`. Logs can contain secrets.

## 8. HCP Terraform
- Organization -> project -> workspace (own state, variables, runs, permissions). Settings flow down unless set to custom.
- `cloud` block (1.1+, replaces `backend "remote"`), no variables; `TF_CLOUD_ORGANIZATION` can set the org. `terraform login`; CI uses `TF_TOKEN_app_terraform_io`.
- No local state file. State is versioned and locked; runs are queued per workspace.
- Variables: Terraform vs environment category, sensitive = write-only, **variable sets** shared; the workspace value wins.
- Remote mode: runs on HCP, uses workspace variables, can't prompt. **Local mode: runs on your laptop, ignores workspace variables.** Agent mode: your network.
- Migration into HCP: `init` asks to copy the existing state -> **yes**.
- Workflows: CLI-, VCS- and API-driven. PR -> speculative plan (never applied). Push to main -> real run. No CLI apply on VCS workspaces.
- Governance: teams/permissions, run triggers, notifications, private registry, no-code modules, run tasks, drift detection, continuous validation.
- Sentinel: advisory / soft-mandatory / hard-mandatory. OPA: advisory / mandatory. Policies run after plan, before apply.
- HCP Terraform = SaaS. Terraform Enterprise = self-hosted.

---

## Roadmap
1. Terraform Associate (004): these labs.
2. Cloud capstone (AWS or Azure free credits): real resources, S3 remote state, own modules for dev/staging/prod, CI, tests, drift detection.
3. Next certification: AWS Solutions Architect Associate, then Terraform Authoring and Operations Professional.
