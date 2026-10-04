# Lab Notes — Task 4: Resources, Data Sources, and Meta-Arguments

## Part B: Experiments

### 1. Remote State Before Initialization
* **Prediction:** The plan will crash because `terraform_remote_state` tries to look up a non-existent state file on disk.
* **Actual Result:** 
```text
Unable to find remote state: No stored state was found for the given workspace in the given backend.
```

### 2. The Hidden Dependency Trap
* **Prediction:** The apply will fail during the plan/data phase because `data.local_file.manifest_check` attempts to read a file (`out/manifest.txt`) that hasn't been generated yet by the managed resource.
* **Actual Result:** 
```text
Read local file data source error … open ./out/manifest.txt: no such file or directory
```
* **Resolution:** Adding `depends_on = [local_file.manifest]` instructs Terraform to defer reading the data source until after the managed resource successfully updates during the apply phase.

### 3. ⭐ The Index-Shift Trap (Critical Exam Case)
* **Prediction:** `by_count` will show resource destructions/modifications for unintended elements due to numerical array shifts. `by_each` will cleanly delete only the target `"api"` resource by its key identifier.
* **Actual Result:** 
  Removed `"api"` from both variables, then ran `terraform plan`:
```text
  # local_file.by_count[1] must be replaced
      ~ filename = "./out/count/api.env" -> "./out/count/worker.env" # forces replacement
  # local_file.by_count[2] will be destroyed
  # (because index [2] is out of range for count)
  # local_file.by_each["api"] will be destroyed
  # (because key ["api"] is not in for_each map)
  # local_file.manifest must be replaced
Plan: 2 to add, 0 to change, 4 to destroy.
```
  * `by_count`: `[1]` was "api" and is now "worker", so it gets **replaced**. `[2]` (the old "worker") no longer exists, so it gets **destroyed**. Two resources were touched although only one service was removed. "worker" itself didn't change, it just moved position.
  * `by_each`: only `["api"]` is destroyed. `["web"]` and `["worker"]` are untouched, because they're tracked by name, not position.
  * Also: `manifest` is replaced because its content lists the services, and `manifest_check` "will be read during apply" because it depends on a resource with pending changes.

### 4. Combining Count and For_Each
* **Prediction:** `terraform validate` will error out immediately because `count` and `for_each` are mutually exclusive meta-arguments.
* **Actual Result:** 
```text
Invalid combination of "count" and "for_each"
```

### 5. Dynamic For_Each over Computed Resource Lists
* **Prediction:** The plan will fail because the hex values of the `random_id` resources are calculated *after* creation, meaning the keys for `for_each` are unknown at plan time.
* **Actual Result:** 
```text
Invalid for_each argument
```

### 6. Lifecycle Upgrades and Downtime (`release_version = "1.1.0"`)
* **Actual Result** (`terraform plan -var=release_version=1.1.0`):
```text
WITH create_before_destroy:
+/- create replacement and then destroy
  # local_file.release_notes will be replaced due to changes in replace_triggered_by
+/- resource "local_file" "release_notes" {

WITHOUT create_before_destroy:
  # local_file.release_notes will be replaced due to changes in replace_triggered_by
-/+ resource "local_file" "release_notes" {

Both: Plan: 1 to add, 2 to change, 1 to destroy.
```
  * `+/-` = new one created first, then old one destroyed, so **no downtime**.
  * `-/+` = old one destroyed first, then new one created, so **there's a gap (downtime)**. This is Terraform's default.
  * The "2 to change" are `terraform_data.release` and `terraform_data.notify`, updated in place (`~`) because their `input` changed.
* **Note on Content Isolation:** By removing the inline version string calculation from the file's `content` property, the resource is no longer forced into an update by content text mutations. Now, the plan delta isolates the `replace_triggered_by` attribute hook, cleanly triggering replacement strictly due to its tracked upstream dependency block lifecycle constraint.

### 7. Ignored Code Mutations vs Physical Drift
* **Prediction:** Changing code string layout does nothing due to `ignore_changes`. Physically deleting the file forces Terraform to recreate it.
* **Actual Result:** Modifying code results in zero changes planned. Manually running `rm out/banner.txt` forces an active recreation plan because `ignore_changes` only bypasses updates for existing attributes; it cannot protect a resource block if the underlying asset disappears entirely from the filesystem.

### 8. The Prevent Destroy Lockout
* **Prediction:** The destroy loop will abort midway because `local_file.audit_log` is protected by `prevent_destroy = true`.
* **Actual Result:** 
```text
Instance cannot be destroyed
```

### 9. Provisioner Execution Lifecycles & Race Solutions
* **Actual Result**: contents of `out/deploy.log` after each step:
```text
1. first apply              -> Deployed 1.0.0
2. apply with no changes    -> (nothing added: "No changes")
3. apply -replace=terraform_data.notify
     terraform_data.notify: Destroying...
     terraform_data.notify: Provisioning with 'local-exec'...   <- destroy-time
     terraform_data.notify: Creating...
     terraform_data.notify: Provisioning with 'local-exec'...   <- create-time
                            -> Destroyed / Deployed 1.0.0 added
4. destroy                  -> Destroyed added

Final log:
Deployed 1.0.0
Destroyed
Deployed 1.0.0
Destroyed
```
  * Provisioners only run when the resource is **created** or **destroyed**, never on an apply with no changes, and not on in-place updates either.
  * `-replace` runs **both**: destroy-time first, then create-time.
  * `deploy.log` survives `terraform destroy` because no resource owns it (it was written by a shell command, not by Terraform).
* **Race Fix Implemented:** I chose to implement explicit ordering by adding `depends_on = [local_file.manifest]` straight into the `terraform_data.notify` configuration block. This forces Terraform to completely establish the `out/` parent layout tree structure on disk before launching the decoupled parallel provisioner shell engine execution threads.

### 10. State Addressing Layout Structure
* **Prediction:** Count uses numeric notation indexes ([0]). For_each addresses wrap strings inside escaped quotes (`["web"]`).
* **Actual Result:** `terraform state list` outputs structured key indicators. When running commands on individual items, single quotes are required—e.g., `'local_file.by_each["web"]'`—to prevent bash terminal shells from incorrectly parsing the evaluation characters as standard wildcard path expansions.

### 11. Dependency Tree Mapping Checks
* **Actual Result** (`terraform graph | grep manifest`):
```text
WITH depends_on:
  "data.local_file.manifest_check" -> "local_file.manifest";
  "terraform_data.notify" -> "local_file.manifest";

WITHOUT depends_on on manifest_check:
  (no edge from manifest_check at all)
```
  * An arrow `A -> B` means "A depends on B", so B is built first.
  * Without `depends_on`, Terraform sees no link (the data source only has a path *string*), so it may read the file before it exists. That's the error from Experiment 2.
  * The second edge is the race fix from Experiment 9.

---

## Part C: Core Questions

### 1. Resource Block vs Data Block
* **Resource Block (Managed):** Declares components Terraform is responsible for building, modifying, updating, and destroying throughout their lifecycle.
* **Data Block (Read-Only):** Fetches read-only properties from an infrastructure component defined outside the local config. Running `terraform destroy` will never delete or impact the source asset a data block reads.

### 2. Count vs For_Each & The Index-Shift Problem
* **Usage:** Use `count` for multiplying simple, identical resources. Use `for_each` when creating collections of distinct elements based on maps or unique sets.
* **Index-Shift Trap:** If you delete an item from the middle of a list managed by `count`, every subsequent item shifts down by one index position. Terraform interprets this index shift as a change to all subsequent resources, causing it to update or replace resources that shouldn't be touched.

### 3. Why must `for_each` keys be known at plan time?
* Terraform requires all resource addresses to be completely calculated during the plan phase to build its dependency graph and state tracking matrix. If keys are computed later during apply, Terraform cannot know how many resources it needs to manage or what their state addresses will be.

### 4. Implicit vs Explicit Dependencies
* **Implicit Dependency:** Created naturally by passing an attribute of one resource directly into another argument (e.g., `DB_HOST = data.terraform_remote_state.platform.outputs.db_host`).
* **Explicit Dependency:** Formed by manually writing a `depends_on` block (e.g., `depends_on = [local_file.manifest]`). This is required when a resource relies on another asset being created first, but no direct data reference link exists in the code arguments. It should not be overused because it unnecessarily blocks concurrent resource creation and slows down applies.

### 5. The Four Lifecycle Arguments
* `create_before_destroy`: Allocates and initializes the replacement resource *before* destroying the old object to avoid service downtime.
* `prevent_destroy`: Rejects any execution plan that would cause the protected resource to be removed (destroy, or a replacement). Error: "Instance cannot be destroyed".
* `ignore_changes`: Instructs Terraform to ignore differences for specified resource attributes when planning resource updates, whether the difference comes from code changes or external changes. The value is still used when the resource is first created, and it doesn't stop Terraform recreating the resource if it disappears (Experiment 7).
* `replace_triggered_by`: Forces a resource reconstruction if a targeted external resource or variable reference experiences any modifications.

### 6. Plan Delta Symbols
* `~`: The resource will be updated in-place (no replacement needed).
* `+/-`: The resource will be destroyed and recreated, but the **replacement is built first** (due to `create_before_destroy`).
* `-/+`: The resource will be destroyed and recreated, meaning the **old asset is dropped first** before the new one is deployed.

### 7. Provisioners as a Last Resort
* **Why Last Resort:** Provisioners do not follow declarative models, do not save status records to state history files, and cannot track success flags natively.
* **Failure Impact:** If a create-time provisioner fails, Terraform marks the entire parent resource as **"tainted"**. It will be completely destroyed and recreated on the next apply run.
* **Destroy-Time Restraints:** Destroy-time provisioners can only access `self` values because the rest of the configuration graph may have already been destroyed by the time the provisioner executes.

### 8. `terraform_remote_state` Capabilities and Concerns (REVISED)
* **Exposed Visibility:** The block code interface can **only** expose parameters explicitly defined inside the producer module's root outputs block (e.g., `.outputs.db_host`). It cannot directly access internal components like `random_pet.db`.
* **Security Concern:** To read those root outputs, the consumer engine requires read privileges over the **entire target state architecture file**. If that file contains embedded backend secrets, deployment access passwords, or private environment values, they become exposed to the consumer.
* **Safer Alternatives:** Use the dedicated `tfe_outputs` data source if working within HCP Terraform to limit visibility strictly to output metadata, or publish non-sensitive operational strings directly to distributed secret parameter spaces like AWS SSM Parameter Store (read with the `aws_ssm_parameter` data source) or HashiCorp Vault, so the consumer only gets the values it needs.
