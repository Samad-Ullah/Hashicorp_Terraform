# Task 6 - State management

Exam objectives: **2d** (how Terraform uses state), **6a-6d** (local backend, locking, remote backend, drift),
**7a-7c** (import, inspecting state with the CLI, verbose logging).
All results below are real output from Terraform 1.16.4 and Consul 2.0.4 (dev mode) on this machine.

---

## 0. What state is and why it exists

Code says **what you want**. State is Terraform's **record of what it created**. Before every plan, Terraform
**refreshes**: it asks the real world for current values, then compares **code vs state vs reality**.

State does four jobs:
1. **Mapping**: links an address in code (`local_file.service["web"]`) to a real object (its ID).
2. **Metadata**: dependencies, so Terraform can destroy in the right order even after you delete code.
3. **Performance**: cached attribute values.
4. **Collaboration**: shared remote state + locking lets a team work on the same infrastructure.

State contains **secrets in plain text**, so never commit it, and protect the backend.

---

## Step 1 - Inside a state file

| Field | My value | Meaning |
|---|---|---|
| `version` | 4 | format of the state **file** (not Terraform's version) |
| `terraform_version` | 1.16.4 | Terraform that last wrote it (older versions refuse to read newer state) |
| `serial` | 11 | **+1 every time state is written** (apply, import, `state mv`, ...) |
| `lineage` | `e8b38a8b-...` | unique ID given when the state was **created**, **never changes** |
| `resources` | 2 entries | `for_each` instances are stored with an `index_key` (`"api"`, `"web"`) |

- `serial` + `lineage` stop you overwriting **newer** state with **older** state, or with a **different** state.
  That's why you never edit state by hand.
- `terraform show` = the **whole** state (or a saved plan file). `terraform state show <address>` = **one** resource.
- `terraform state list` = all addresses. In bash, quote addresses with brackets: `'local_file.svc["web"]'`.

---

## Step 2 - The `local` backend and migrating state

```hcl
terraform {
  backend "local" {
    path = "state/dev.tfstate"
  }
}
```
- The **backend** decides **where state is stored** and **whether locking works**. Default = `local` (`terraform.tfstate`).
- Any change to the backend block needs `terraform init` again. Before that, `plan` fails with:
  `Error: Backend initialization required, please run "terraform init"`
  `Reason: Initial configuration of the requested backend "local"`
- `terraform init -migrate-state` copied the state: `state/dev.tfstate` = 3655 bytes, old `terraform.tfstate` = **0 bytes**.
- **Migrating moves the record only.** No real resource was touched.

| init flag | Meaning |
|---|---|
| `-migrate-state` | **copy** existing state to the new backend |
| `-reconfigure` | **ignore** the old backend, start fresh, copy nothing |

**Variables are NOT allowed in backend blocks** (`Error: Variables not allowed`), because the backend is set up
during `init`, before variables are evaluated. On a folder that's already initialised, you may first see
`Error: Backend configuration changed` instead.

---

## Step 3 - Locking

Two operations at once on the same state would overwrite each other. Locking prevents that.

While `terraform apply` was running (a 40-second `time_sleep`), a hidden file appeared:
`state/.dev.tfstate.lock.info`
```json
{"ID":"310e1db8-...","Operation":"OperationTypeApply","Who":"root@DESKTOP-HU962IE",
 "Version":"1.16.4","Created":"2026-10-06T13:08:35Z","Path":"state/dev.tfstate"}
```
A second `terraform plan` at the same time:
```
Error: Error acquiring the state lock
Error message: resource temporarily unavailable
```
With `terraform plan -lock-timeout=60s`, it printed `Acquiring state lock. This may take a few moments...`,
**waited ~30 s** until the apply finished, then ran normally.

- Locking is **automatic** for every operation that can write state.
- `terraform force-unlock <LOCK_ID>`: removes a **stuck** lock (for example after a crash). Never use it while someone is still running.
- `-lock=false`: skips locking, so two runs can corrupt state. Dangerous.
- Backends with locking: local, s3, azurerm, gcs, consul, HCP Terraform (and more).

---

## Step 4 - Remote backend (Consul) with partial configuration

`backend.tf` (in git):
```hcl
terraform {
  backend "consul" {
    path = "shopcart/dev"
  }
}
```
`consul.hcl` (passed at init):
```hcl
address = "127.0.0.1:8500"
scheme  = "http"
```
```bash
terraform init -migrate-state -backend-config=consul.hcl
```
- State is now in Consul's key-value store under **`shopcart/dev`** (`consul kv get -keys shopcart/`).
- `state/dev.tfstate` was **NOT deleted** (still 4160 bytes). That's a stale copy, so **delete old local state after a migration**.
- **Partial configuration** = leave some settings out of the backend block and pass them with `-backend-config`.
  Use it for: a different server or bucket per environment, and keeping credentials (tokens) out of git.
- `-backend-config` values are saved in **`.terraform/terraform.tfstate`**, so never commit `.terraform/`.
- Real teams: S3 (`use_lockfile = true`), azurerm, gcs, or HCP Terraform. Same idea, different backend.

---

## Step 5 - Renaming without destroying: `moved` and `state mv`

Renaming `random_pet "db"` -> `"database"` **without** telling Terraform:
```
  # random_pet.database will be created
  # random_pet.db will be destroyed
  # (because random_pet.db is not in configuration)
  # local_file.svc["api"] must be replaced
  # local_file.svc["web"] must be replaced
Plan: 3 to add, 0 to change, 3 to destroy.
```
Terraform doesn't understand "rename": it sees one resource gone and a new one added. On a real database = **data loss**.

**Fix 1 - `moved` block (recommended):**
```hcl
moved {
  from = random_pet.db
  to   = random_pet.database
}
```
-> plan: `random_pet.db has moved to random_pet.database`, `0 to destroy`. Same pet (`sincere-collie`), nothing recreated.

**Fix 2 - CLI:**
```bash
terraform state mv 'local_file.svc' 'local_file.service'
```
-> moved **both** instances (`["web"]`, `["api"]`) at once. Then `plan` = No changes.

| | `moved` block | `terraform state mv` |
|---|---|---|
| Shown in plan, reviewed in git | yes | no, instant and invisible |
| Works for teammates' states automatically | yes | no, everyone must run it |

**When can you delete a `moved` block?** When **every** state using this code has been applied with it.
One state (this lab) = safe. dev/staging/prod or a shared **module** = keep it (often forever). When in doubt, keep it.

Also used in Step 9: adding `count` changes the address `consul_key_prefix.legacy` -> `consul_key_prefix.legacy[0]`,
so a `moved` block was needed there too.

---

## Step 6 - Stop managing without destroying: `removed` and `state rm`

Deleting the `time_sleep.deploy` block from code:
```
  # time_sleep.deploy will be destroyed
  # (because time_sleep.deploy is not in configuration)
Plan: 0 to add, 0 to change, 1 to destroy.
```
With a `removed` block (Terraform 1.7+):
```hcl
removed {
  from = time_sleep.deploy
  lifecycle {
    destroy = false
  }
}
```
```
  # time_sleep.deploy will no longer be managed by Terraform, but will not be destroyed
Plan: 0 to add, 0 to change, 0 to destroy.
Warning: Some objects will no longer be managed by Terraform
```
`terraform state rm 'local_file.service["api"]'` while the resource was **still in the code**:
```
  # local_file.service["api"] will be created
Plan: 1 to add, 0 to change, 0 to destroy.
```
`out/api.env` still existed, but Terraform had "forgotten" it, so it wanted to create it again.
In AWS that means `BucketAlreadyExists`, or a silent **duplicate** that costs money.
**Rule:** after `state rm`/`removed`, also remove the code, or let someone else import the object.

---

## Step 7 - Import (bring hand-made things under Terraform)

Created by hand: `consul kv put shopcart/legacy/db_host db1.internal` and `.../db_port 5432`.

```hcl
import {
  to = consul_key_prefix.legacy     # the address I choose
  id = "shopcart/legacy/"           # the real object's ID, in the provider's format
}
```
```bash
terraform plan -generate-config-out=generated.tf   # writes the resource block for me
terraform apply                                     # -> Resources: 1 imported, 0 added, 0 changed, 0 destroyed.
```
Generated code (review it, delete `= null` lines, move it into main.tf):
```hcl
resource "consul_key_prefix" "legacy" {
  datacenter  = "dc1"
  path_prefix = "shopcart/legacy/"
  subkeys = {
    db_host = "db1.internal"
    db_port = "5432"
  }
}
```
- `plan` **reads** the object and writes **code**. Only `apply` writes the import into **state**.
- Terraform only manages what's in state. Without import, it would try to **create** what already exists.
- **Where does the ID come from?** The **format** is in the provider docs (the "Import" section of each resource page).
  The **value** comes from the real object (console, CLI). Examples: S3 bucket = bucket name, EC2 = `i-0abc...`,
  security group = `sg-...`. A wrong ID makes the **plan fail**, and nothing is imported by mistake.
- Not every resource supports import (`local_file` and `consul_keys` don't). Check the docs.

| | `import` block (1.5+) | `terraform import` (CLI) |
|---|---|---|
| Shown in plan | yes (`will be imported`) | no, writes state immediately |
| Generates code | yes (`-generate-config-out`) | no, you write the block first |
| Many at once / `for_each` | yes | one per command |

After a successful import, the `import` block does nothing more. Delete it or keep it as documentation.

**Careful:** `consul_key_prefix` manages **every key under its prefix**. Never point it at `shopcart/`,
because that contains the **state** (`shopcart/dev`).

---

## Step 8 - Drift

Changed by hand: `consul kv put shopcart/legacy/db_host db2.internal`

| Command | Result |
|---|---|
| `terraform plan -refresh-only` | `Note: Objects have changed outside of Terraform` / `"db1.internal" -> "db2.internal"`. **Reports only, proposes nothing** |
| `terraform plan` | `~ "db_host" = "db2.internal" -> "db1.internal"`. Wants to **put it back** (code wins) |
| `terraform apply -refresh-only` | accepts the change **into state** only, the real world is not touched |

After `apply -refresh-only`, a normal `plan` **still** wanted to change it back, because the **code** still said `db1`.
The three real choices:
1. Colleague was **wrong**: `terraform apply` (the code puts it back). This is what happened in the end.
2. Colleague was **right**: **change the code**, then plan = No changes.
3. Only record reality: `apply -refresh-only` (the next normal apply still reverts it).

`-refresh-only` replaced the deprecated `terraform refresh` command (which updated state silently, without a plan).

---

## Step 9 - CLI workspaces

```bash
terraform workspace show / list / new staging / select default / delete staging
```
Code made workspace-aware:
```hcl
filename = "${path.module}/out/${terraform.workspace}/${each.key}.env"
count    = terraform.workspace == "default" ? 1 : 0     # only default owns the legacy keys
```
| | default | staging |
|---|---|---|
| State in Consul | `shopcart/dev` | `shopcart/dev-env:staging` |
| Resources | pet, 2 files, legacy keys | pet, 2 files (no legacy) |
| Files | `out/default/` | `out/staging/` |

- A new workspace starts with an **empty state**, so its plan creates everything.
- Same code, **separate states**. `terraform.workspace` = the current name.
- The backend decides the storage name (Consul: `<path>-env:<name>`, local backend: `terraform.tfstate.d/<name>/`).
- `workspace delete` refuses if the workspace still has resources (deleting would leave **orphans**), and you can't
  delete the workspace you're in. Proper way: `select staging` -> `destroy` -> `select default` -> `delete staging`.
  (`-force` deletes anyway and creates orphans.)
- **Two states must never manage the same object.** That's why `count` kept `legacy` out of staging.
- **CLI workspace ≠ HCP Terraform workspace.** CLI = another state for the same folder (same credentials, same backend).
  HCP = its own variables, permissions, run history, VCS connection.
- For dev/staging/prod with different accounts or credentials, prefer **separate directories + shared modules**.

---

## Step 10 - Debugging with TF_LOG

| Variable | Meaning |
|---|---|
| `TF_LOG` | `TRACE` > `DEBUG` > `INFO` > `WARN` > `ERROR` (`JSON` = TRACE as JSON) |
| `TF_LOG_PATH` | write to a file (otherwise logs go to **stderr**) |
| `TF_LOG_CORE` | Terraform core only (graph, state, backend) |
| `TF_LOG_PROVIDER` | providers only (plugin start, API calls) |

One small `plan` on this config:
| Log | Lines |
|---|---|
| `TF_LOG=TRACE` | 1592 (1269 `[TRACE]`) |
| `TF_LOG_PROVIDER=DEBUG` | 127, e.g. `provider: starting plugin: path=.terraform/providers/.../consul/2.23.0/...` |
| `TF_LOG_CORE=DEBUG` | 71, e.g. `Terraform version: 1.16.4` |

- `TF_LOG=INFO terraform plan` sets it for **one command only**.
- A Terraform crash writes `crash.log` (ignored in `.gitignore`).
- Logs can contain **secrets**, so never commit or share them unchecked.

---

## Exam traps
1. `serial` goes up on every state write. `lineage` never changes.
2. Backend blocks **cannot use variables**. Use partial config (`-backend-config`).
3. `-migrate-state` copies state, `-reconfigure` doesn't. Migration never touches real resources.
4. Locking is automatic. `-lock-timeout` waits, `force-unlock` is for stuck locks only.
5. Renaming a resource without `moved` = **destroy + create**.
6. `moved`/`removed`/`import` **blocks** show in plan. `state mv`/`state rm`/`terraform import` don't.
7. `state rm` on something still in the code = Terraform will try to **create it again**.
8. The import ID format comes from the **provider docs**, and the value from the real object.
9. `plan -refresh-only` shows drift. `apply -refresh-only` writes it to state. The code still wins on the next apply.
10. CLI workspaces = separate states for the same code. They are **not** HCP Terraform workspaces.
11. `TF_LOG` levels: TRACE, DEBUG, INFO, WARN, ERROR. `TF_LOG_PATH` writes them to a file.
