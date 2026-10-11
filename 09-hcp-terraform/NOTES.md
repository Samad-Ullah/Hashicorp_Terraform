# Task 8 - HCP Terraform

Exam objectives: **8a** (create infrastructure with HCP Terraform), **8b** (collaboration and governance),
**8c** (organize workspaces and projects), **8d** (configure the HCP Terraform integration).
All results below are real output from my organization on HCP Terraform (free tier) with Terraform 1.16.4.

```
Organization: samad-shopcart-org  (plan: free_standard)
└── Project: Default Project       (default execution mode: remote)
    ├── shopcart-dev      CLI-driven  - 09-hcp-terraform/            (workspace vars + variable set)
    ├── shopcart-legacy   CLI-driven  - 09-hcp-terraform/migrate-demo (state migrated from local)
    └── shopcart-vcs      VCS-driven  - GitHub repo, working dir 09-hcp-terraform/migrate-demo
```

---

## 0. What HCP Terraform is

| Without HCP Terraform | With HCP Terraform |
|---|---|
| Terraform runs on my laptop | runs on HCP's servers ("remote runs"); output streams to my terminal |
| state in a file / S3 / Consul that I set up | state stored, **locked**, **versioned** and encrypted for me |
| secrets in tfvars or env vars | variables stored in the workspace (sensitive = write-only) |
| "who applied that?" | every run recorded: who, when, what plan, approval comment |
| anyone with credentials can apply | teams and permissions, manual approval, policy checks |

| Product | What |
|---|---|
| **HCP Terraform** | HashiCorp's hosted SaaS (formerly "Terraform Cloud") |
| **Terraform Enterprise** | the **self-hosted** version (own data centre or cloud account) |
| Terraform Community Edition | the free CLI |

**Vocabulary:**
| Term | Meaning |
|---|---|
| Organization | top level: billing, SSO, org-wide settings, policies, variable sets |
| Project | groups workspaces; team permissions and defaults (e.g. execution mode) apply to all of them |
| Workspace | one config + **its own state, variables, runs, permissions** (much more than a CLI workspace!) |
| Run | one plan (+ apply) in a workspace |

Settings flow **down**: organization -> project -> workspace, unless a lower level sets a **custom** value.

**Three workflows:**
1. **CLI-driven**: I type `terraform plan/apply`, it runs remotely (steps 3-5)
2. **VCS-driven**: a push or PR on GitHub starts the run (step 6)
3. **API-driven**: CI pipelines or scripts start runs through the API

---

## Step 1 - Account vs organization

- `samad-shopcart` = my **user account** (a person, used to log in).
- `samad-shopcart-org` = my **organization** (owns workspaces, state, runs, variables, teams, billing).
- At first I only had a user, and the API showed `orgs: []`. The `cloud` block can only **point at** an existing
  organization, so I created it in the browser. Workspaces, on the other hand, are created automatically by `terraform init`.
- Organizations can also be managed with code (the `tfe` provider, `tfe_organization`). That's advanced and not needed for the exam.

---

## Step 2 - `terraform login`

```bash
terraform login        # opens a URL -> generate a token (I chose a 30-day expiry) -> paste it
```
- The token is saved in `~/.terraform.d/credentials.tfrc.json` (home folder, NOT the project, so it can't be committed).
  Permissions `-rw-------`. Never print or share it.

| Token | Belongs to | Use |
|---|---|---|
| User token | me | laptop, `terraform login` |
| Team token | a team | CI pipelines |
| Organization token | the organization | admin automation (create workspaces, teams) |

- In CI: no `terraform login`. Set the env var **`TF_TOKEN_app_terraform_io`** (hostname with dots -> underscores) as a CI secret.

---

## Step 3 - The `cloud` block and a remote run

```hcl
terraform {
  required_version = ">= 1.12"

  cloud {
    organization = "samad-shopcart-org"
    workspaces {
      name = "shopcart-dev"          # created automatically on first init if missing
    }
  }
  ...
}
```
- `cloud` block = the modern way (since 1.1). The older `backend "remote"` does the same job.
- Like `backend`, it **can't use variables**. `organization` can come from the env var `TF_CLOUD_ORGANIZATION` instead.
- `workspaces { name = "..." }` = one workspace. `workspaces { tags = [...] }` = a group, chosen with `terraform workspace select`.
- `terraform plan` printed `Running plan in HCP Terraform. Output will stream here.`, a run URL, and `Waiting for the plan to start...`.
- `apply` asked: `Do you want to perform these actions in workspace "shopcart-dev"?`
- **There is no `terraform.tfstate` on my laptop.** State is in HCP (Workspace -> States shows every version).
  `terraform state list` and `terraform output` still work, because they download it.
- Runs are **queued one at a time per workspace**, which is how locking works in HCP.
- With remote execution, a `local_file` would be written on HCP's temporary machine and disappear.
  That's why this lab only uses `random_pet` and `terraform_data`.

---

## Step 4 - Workspace variables and variable sets

A remote run **can't prompt** (there's no keyboard on HCP's server). With `owner` missing:
```
Waiting for the plan to start...
Terraform v1.16.4
on linux_amd64
Error: No value for required variable
  on variables.tf line 5:   variable "owner" {
Operation failed: failed running terraform plan (exit 1)
```
(Locally, in Task 2, Terraform **asked** for the value. Remotely, it **fails**.)

| Category | Becomes | Use |
|---|---|---|
| **Terraform variable** | a `variable` value (like `-var`) | `environment`, `owner` |
| **Environment variable** | a shell env var on the run machine | provider credentials (`AWS_ACCESS_KEY_ID`, `ARM_CLIENT_SECRET`), `TF_LOG` |

My setup:
| Variable | Where | Note |
|---|---|---|
| `environment = "dev"` | workspace `shopcart-dev` | Terraform variable |
| `db_password` | workspace `shopcart-dev` | **sensitive**: write-only, the API returned no value, only replaceable |
| `owner = "samad"` | **variable set** `shopcart-common`, applied to `shopcart-dev` | shared across workspaces |

- My first variable set was **empty** (the variable wasn't saved), so `owner` was still missing. Always check that the variable appears in the list.
- **Variable sets** = define once, apply to many workspaces / a project / the whole org.
  If a variable is set in both, the **workspace value wins** over the variable set.
- Sensitive in HCP hides the value in the UI and API. If code puts it in a resource or output, it is still in **state**.

Apply result:
```
-/+ resource "random_pet" "db" {
      + prefix = "dev" # forces replacement
random_pet.db: Destroying... [id=immune-pangolin]
random_pet.db: Creating...  ->  dev-adequate-cow
Outputs: db_host = "dev-adequate-cow.db.internal", owner = "samad", release = "1.0.0"
```
`prefix` is force-new, so the pet was replaced. The default order is destroy first, then create (`-/+`).

---

## Step 5 - Execution modes and state migration

| Mode | Where the run happens | State | Workspace variables used? |
|---|---|---|---|
| **Remote** (default) | HCP's servers | HCP | yes |
| **Local** | my laptop | HCP | **no** |
| Agent | an agent in my own network (paid; needs an agent pool) | HCP | yes |

Switching `shopcart-dev` to **Local (custom)**: the first try didn't work, because I didn't click **Save settings** at the
bottom of the page (the API still showed `execution-mode: remote`). After saving, `terraform plan`:
```
var.db_password
  Enter a value:
```
- No `Running plan in HCP Terraform`, no `Waiting for the plan to start...`: it ran on my laptop.
- Workspace variables and variable sets were **ignored**, so Terraform **prompted** (alphabetical order: `db_password` first).
- In Local mode, HCP is **only a state backend** (storage, locking, history).
- Then I set it back to **Project default** (= remote).

**Migrating local state into HCP** (what companies do when they adopt HCP Terraform):
1. `migrate-demo/` with local state: `pet = "touched-sheepdog"`, local `terraform.tfstate` = 772 bytes.
2. Added a `cloud` block (workspace `shopcart-legacy`) and ran `terraform init`:
   ```
   Should Terraform migrate your existing state?
   Answer "yes" to copy the latest state snapshot to the configured HCP Terraform workspace.
   Answer "no" to ignore the existing state and just activate the configured HCP Terraform workspace ...
   ```
   `yes` = like `-migrate-state` (copy). `no` = like `-reconfigure` (start empty, so the old pet would be orphaned).
3. Result: `pet = "touched-sheepdog"` (same pet), `shopcart-legacy` has 1 resource, `plan` = No changes.
   Local `terraform.tfstate` = 0 bytes, `terraform.tfstate.backup` = 772 bytes (deleted afterwards: stale copies can hold secrets).

---

## Step 6 - VCS-driven workflow (GitHub)

Setup: New workspace -> Version Control Workflow -> GitHub.com -> authorize the **GitHub App** (only the
`Hashicorp_Terraform` repo = least privilege) -> workspace `shopcart-vcs`.
- Chrome blocked the GitHub pop-up (`Failed to install GitHub App - Please disable pop-up blocker`).
  Fix: the pop-up icon left of the star in the address bar -> always allow for app.terraform.io.
- The workspace name defaulted to the repo name (`Hashicorp_Terraform`), so I renamed it to `shopcart-vcs`.
- **Terraform Working Directory** = `09-hcp-terraform/migrate-demo`. A repo with many folders needs it, otherwise HCP
  runs the repo root (no .tf files).
- File triggers are off, so **any** push to the repo starts a run. In big repos, enable "only trigger runs when files
  in specified paths change".

Runs:
```
run-bWRePg6FuPDtuzKT  applied | source: tfe-ui                    | Triggered via UI      -> pet = "curious-raptor"
run-cVaJCnhhDUwPYpS1  applied | source: tfe-configuration-version | Add greeting output   <- started by my git push
outputs: greeting = "Hello from curious-raptor!", pet = "curious-raptor"
```
- A new VCS workspace starts with **empty state**, so it created a new pet (`curious-raptor`), separate from `shopcart-legacy`.
- `git push` -> HCP planned automatically, with the **commit message as the run title** -> status `planned`
  (waiting for approval) -> I clicked **Confirm & apply** with a comment. **Nobody applied from a laptop.**
- The Runs page doesn't always refresh by itself (press F5).
- **Pull request** -> **speculative plan** (plan only, can never be applied), result shown on the PR in GitHub.
- Push or merge to the tracked branch (default `main`) -> normal run.
- **`terraform apply` from the CLI is not allowed on a VCS-connected workspace.** `terraform plan` from the CLI = speculative plan.

---

## Step 7 - Collaboration and governance features (recognise them for the exam)

| Feature | What it does |
|---|---|
| **Teams and permissions** | e.g. devs can plan, leads can apply (read / plan / write / admin on workspaces or projects) |
| **Run approval / auto-apply** | manual "Confirm & apply" (default) or auto-apply per workspace |
| **Notifications** | run events -> Slack, Teams, email, webhooks |
| **Run triggers** | when workspace A applies, queue a run in workspace B (e.g. network -> app) |
| **Private registry** | share own modules and providers in the org: `app.terraform.io/<org>/<name>/<provider>` |
| **No-code modules** | non-Terraform users create infrastructure from an approved module with a form |
| **Policy as code** | rules checked on every run, **after plan, before apply** |
| **Run tasks** | call external tools (security scan, cost check) at run stages; they can pass or block |
| **Drift detection** | background **refresh-only plans** that alert on changes outside Terraform (automated Task 6 step 8) |
| **Continuous validation** | periodically re-checks `check` blocks and pre/postconditions (Task 5) |

**Sentinel vs OPA:**
| | Sentinel | OPA |
|---|---|---|
| By | HashiCorp | open source (CNCF) |
| Language | Sentinel | Rego |
| Enforcement | **advisory** (warn), **soft-mandatory** (blocks, can be overridden), **hard-mandatory** (blocks, no override) | **advisory**, **mandatory** |

Policies are grouped in **policy sets**, applied to the org, projects or workspaces.
Which features are in which paid tier changes over time, so check HashiCorp's pricing page.

---

## Exam traps
1. User account ≠ organization. The `cloud` block points at an existing org; workspaces are created by `init`.
2. `cloud` block (1.1+) replaces `backend "remote"`. No variables inside; `TF_CLOUD_ORGANIZATION` can supply the org.
3. With a `cloud` block there's **no local state file**. State is versioned and locked in HCP.
4. Remote runs **can't prompt**: missing variables = error. Set them in the workspace or a variable set.
5. Terraform variable vs environment variable category. Sensitive = write-only. Workspace value beats variable set.
6. **Local execution mode ignores workspace variables**. HCP is then only a state backend.
7. Migrating into HCP: answer **yes** to copy the state. The infrastructure is not touched.
8. VCS workspace: PR -> speculative plan (never applied); push to main -> real run; **no CLI apply**.
9. Repos with many folders need a **working directory** (and ideally file trigger paths).
10. Sentinel levels: advisory / soft-mandatory / hard-mandatory. Policies run after plan, before apply.
11. CI authenticates with `TF_TOKEN_app_terraform_io`, not `terraform login`.
12. HCP Terraform = SaaS. Terraform Enterprise = self-hosted.
