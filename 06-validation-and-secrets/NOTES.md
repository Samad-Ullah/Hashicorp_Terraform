# Task 5 - Validation, checks, sensitive data and Vault

Exam objectives: **4g** (custom conditions) and **4h** (sensitive data and Vault).
All results below are real output from Terraform 1.16.4, Vault 2.1.1 and the Vault provider 5.12.

---

## 1. The four ways to make Terraform check things

| Tool | Where | When it runs | If it fails |
|---|---|---|---|
| `validation` | inside a `variable` block | first, before anything is planned | **Error**: `Invalid value for variable` |
| `precondition` | `lifecycle {}` of a resource, data source or output | before that object is planned/applied | **Error**: `Resource precondition failed` |
| `postcondition` | `lifecycle {}`, can use `self` | as soon as the result is known (can be at plan time!) | **Error**: `Resource postcondition failed` |
| `check` block | top level, on its own | end of every plan and apply | **Warning only**: the apply still completes |

- A validation can only look at **variables**. A precondition can look at **anything**: variables, locals, other resources, data sources.
- Since Terraform 1.9, a validation can use **other variables** (cross-variable validation).
- A variable can have **several** validation blocks. Terraform runs **all** of them and shows every error.
- `can(expr)` turns "error" into `false`. That's why it's used with `regex()` in validations.

---

## 2. Results I saw

### Step 3 - first validation (`environment`)
`-var=environment=qa`:
```
Error: Invalid value for variable
  │ var.environment is "qa"
The environment value must be one of 'dev', 'staging', or 'prod'.
```
Terraform stopped **before planning anything**.

### Step 4 - two validations on `app_name`
| Input | Errors | Why |
|---|---|---|
| `Shop_Cart` | 1 | characters (uppercase and `_`) |
| `ab` | 1 | too short |
| `AB` | **2** | breaks **both** rules, and Terraform shows both errors at once |
| `shop-cart` | 0 | valid |

### Step 5 - cross-variable validation (`replicas`)
`condition = var.environment != "prod" || var.replicas >= 3` ("if prod, then at least 3")
| Command | Result |
|---|---|
| prod, replicas 1 | Error (`var.replicas is 1`) |
| prod, replicas 3 | OK |
| dev, replicas 1 | OK |

### Step 6 - precondition (`replicas <= 10`)
`-var=replicas=50` with environment dev:
```
Error: Resource precondition failed
  │ var.replicas is 50
```
The **validation** let 50 through (in dev, "not prod" is already true), so the **precondition** caught it. Two layers catch different mistakes.

### Step 6b - postcondition looking for `"XYZ="`
It failed during **`plan`**, not apply. The file `content` comes from my code, so it's **already known at plan time**, and a postcondition runs **as soon as its values are known**. "Post" means "after Terraform knows the result", not "after apply".

### Step 7 - check block (`health.txt` must contain `OK`)
| `health.txt` | Result |
|---|---|
| missing | `Warning: Read local file data source error` -> **Apply complete!** |
| `DOWN` | `Warning: Check block assertion failed` -> **Apply complete!** |
| `OK` | no warning -> **Apply complete!** |

A check block **never blocks** a deployment. It only reports, which makes it useful for health monitoring.

**Bonus - state locking:** while my `terraform apply` was waiting for "yes", another `terraform plan` failed with
`Error: Error acquiring the state lock`. The lock info was in `.terraform.tfstate.lock.info`.

### Step 8 - Vault data source (the old way)
```hcl
data "vault_kv_secret_v2" "db" { mount = "secret"  name = "shopcart/db" }
```
- `validate` warning: **`Deprecated. Please use new Ephemeral KVV2 Secret resource`**
- `grep -c "Sup3rS3cret" terraform.tfstate` -> **2**, even though I **never used the password**, only the username.
  A data source stores **everything it reads** into state, in plain text.
- When I edited `out/app.env` by hand, the next `apply` put it back. That's **drift**: Terraform owns that file, so you change the **code**, not the file.

### Step 9 - sensitive outputs
- Output of the Vault username without `sensitive = true` ->
  `Error: Output refers to sensitive values`. The **provider** marked it sensitive, not me.
- `output "config_path" { value = local_file.app_config }` (the whole object) also failed, because the object includes the
  sensitive `content`. Fix: output only `.filename`. **Sensitivity spreads**: anything built from a sensitive value becomes sensitive.
- `terraform output` -> `db_user = <sensitive>`, but `terraform output db_user` -> `"shopcart_app"` (revealed!).
- `terraform state show` -> `content = (sensitive value)`, because the whole file became sensitive.

### Step 10 - ephemeral resource (the safe way)
```hcl
ephemeral "vault_kv_secret_v2" "db" { mount = "secret"  name = "shopcart/db" }
```
Using it in normal places is blocked at **validate** time:
- in `local_file.content` -> `Error: Invalid use of ephemeral value` ...
  *"because it is not a write-only attribute and must be persisted to state."*
- in a root output -> `Error: Ephemeral value not allowed`
  (and `ephemeral = true` on a root output -> `Ephemeral outputs are not allowed in context of a root module`)

After switching: `terraform.tfstate` -> **0**, but `terraform.tfstate.backup` -> **2**.
The backup is the **previous** state, so old secrets stay in backups and history (and S3 versions!). Clean them up and **rotate** the secret.

### Step 11 - write-only argument
```hcl
ephemeral "random_password" "reporting" { length = 16 }

resource "vault_kv_secret_v2" "reporting" {
  mount = "secret"
  name  = "shopcart/reporting"
  data_json_wo = jsonencode({
    username = ephemeral.vault_kv_secret_v2.db.data["username"]
    password = ephemeral.random_password.reporting.result
  })
  data_json_wo_version = 1
}
```
- In Vault: `username shopcart_app`, a 16-character password, version 1.
- `grep` for the password in state -> **0**.
- State only stores `"data_json_wo": null` and `"data_json_wo_version": 1`.
- Ephemeral resources **Open** and **Close** (they don't Create/Read) and never appear in `terraform state list`.

### Step 12 - rotation, destroy, dev mode
- **12a:** `terraform plan` -> **No changes**, even though a new random password was generated.
  Terraform can't compare a value it never stored, so it only looks at `data_json_wo_version`.
- **12b:** `data_json_wo_version = 2` + apply -> a new password in Vault (Vault version 2). That's a **secret rotation**.
  The two "2"s are different counters: mine (= "send again") and Vault's own KV history.
- **12c:** `terraform destroy` -> `Resources: 2 destroyed`.
  - `shopcart/reporting` (created by a `resource`) -> deleted. It's a **soft delete** in KV v2 (`deletion_time` set,
    `destroyed false`, and version 1 still exists). `delete_all_versions = true` removes everything.
  - `shopcart/db` (only **read** by `ephemeral`) -> **untouched**. Terraform never deletes what it doesn't own.
- **12d:** after restarting Vault:
  - `terraform plan` -> `Error: Unable to Read Resource from Vault ... Vault response was nil`
    Ephemeral resources are opened on **every plan**, so Terraform needs Vault even just to plan.
    (If Vault is stopped completely, the error is "connection refused".)
  - `vault kv get -mount=secret shopcart/db` -> `No value found`. **Dev mode is in-memory**, so a restart wipes everything.

---

## 3. Questions

**1. sensitive vs ephemeral vs write-only: which keep secrets out of state?**

| | Hidden in CLI | In state / plan file | Since |
|---|---|---|---|
| `sensitive = true` | yes | **yes, plain text** | 0.14 |
| `ephemeral` (variables, resources) | yes | **no, never** | 1.10 |
| write-only arguments (`_wo`) | yes | **no, never**, only a `_version` number | 1.11 |

`sensitive` protects the **screen**. `ephemeral` and write-only protect the **state**.

**2. Why did the Vault provider deprecate the KV data source?**
Because a data source saves **everything it reads** into state in plain text. The ephemeral resource reads the
secret, uses it during the run, and forgets it.

**3. How should Terraform log in to Vault in CI? What must never be in git?**
Through **environment variables** (`VAULT_ADDR`, `VAULT_TOKEN`) or an auth method made for machines
(AppRole, or JWT/OIDC from the CI system), never with the root token. Never commit tokens, passwords,
`*.tfvars` with secrets, `*.tfstate` or `*.tfstate.backup`, or saved plan files.

**4. Why is Vault dev mode not for production?**
1. In-memory storage: a restart deletes all secrets (seen in step 12d).
2. It is auto-unsealed and uses a root token you choose (`root`), so there's no real protection.
3. Plain HTTP without TLS: traffic can be read on the network.

---

## 4. Exam traps
1. `check` failures are **warnings**. validation/precondition/postcondition failures are **errors**.
2. `sensitive` is **not** encryption. The value is still in state in plain text.
3. `self` only works in **postconditions** (and provisioners).
4. A postcondition can fail at **plan** time if its values are already known.
5. Ephemeral values can't go into normal resource arguments or root outputs.
6. Write-only values are only re-sent when you **bump the `_version`**.
7. Destroy only deletes what Terraform **created**, never what it only read.
