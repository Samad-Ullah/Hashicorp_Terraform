# Task 7 - Modules

Exam objectives: **5a** (module sources), **5b** (variable scope), **5c** (using modules), **5d** (module versions).
All results below are real output from Terraform 1.16.4 on this machine.

```
08-modules/
├── modules/
│   ├── service_config/   child module: one .env file per service (published as v1.0.0 and v2.0.0)
│   └── service_index/    child module: index.txt with all service URLs (step 7)
├── app/                  root module: calls service_config v1 (from GitHub), dir/template (Registry), service_index (local)
└── payments/             root module: calls service_config v2 (from GitHub)
```

---

## 1. What a module is

- **Every folder of `.tf` files is a module.**
- The folder where you run `terraform` = **root module**. A module called by another = **child module**.
- **Never run `terraform init/plan/apply` inside a child module folder.** When I did, Terraform treated it as a root,
  nobody passed `urls`, so it **prompted** for `var.urls`. It also created `.terraform/`, a lock file and state in the module folder.
- Standard layout: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` (+ `README.md`).
- A child module declares `required_providers` but has **no `provider` block**. It **inherits** the root's providers.
- Name the main resource of a small module `this` (convention).
- Inside a module, `path.module` = the module's own folder. Use `path.root` for the folder where Terraform runs.

---

## 2. How values flow (variable scope)

```
 app/main.tf (ROOT)                       modules/service_config/ (CHILD)
 module "web" {
   source = "../modules/..."   ── ① where the code is
   port   = 8080  ───────────── ② ──▶  variable "port" { type = number }   ③ arrives, ④ type-checked + validated
 }                                        main.tf:   PORT=${var.port}      ⑤ used as var.port
                                          outputs.tf: output "file_path"   ⑥ the only way out
 module.web.file_path  ◀──────── ⑦ ─────
```
- Module = function: `variable` = parameters, `module` block = the call, `output` = return values.
- Every argument in a `module` block must match a `variable` in the child. Missing a required one = `Missing required argument`.
- Inputs with a default are optional. Inputs **without** a default are required. I removed `default = ""` from `name`
  so callers can't forget it.
- **The child can't see the root's variables.** Using `var.services` inside the child gave:
  `Error: Reference to undeclared input variable`
- **The root can't see inside the child.** Only outputs: `module.<name>.<output>`.
- Resources inside a module get the module in their address: `module.web.local_file.this`,
  `module.service["api"].local_file.this`.

---

## 3. Calling a module many times

```hcl
module "service" {
  source   = "../modules/service_config"
  for_each = var.services            # { web = 8080, api = 8081, worker = 9000 }

  name    = each.key
  port    = each.value
  db_host = "db.shopcart.internal"
}

output "config_paths" {
  value = { for name, svc in module.service : name => svc.file_path }
}
```
- `module` blocks support `for_each`, `count` and `depends_on` (since 0.13).
- Every **new** `module` block needs `terraform init`.
- Switching from `module "web"` + `module "api"` to `module "service"` changes the addresses.
  Use `moved` for a whole module call:
  ```hcl
  moved {
    from = module.web
    to   = module.service["web"]
  }
  ```
- Using a module's outputs in another resource creates an **implicit dependency** (no `depends_on` needed).
  `terraform graph` showed: `"local_file.service_index" -> "module.service.local_file.this"`

---

## 4. Validation inside the module

```hcl
variable "port" {
  type = number
  validation {
    condition     = var.port >= 1024 && var.port <= 65535
    error_message = "The port number must be a non-privileged port between 1024 and 65535 (inclusive)."
  }
}
```
`terraform plan -var='services={web=80, api=8081}'`:
```
Error: Invalid value for variable
  on main.tf line 6, in module "service":          <- the CALLER's line (root)
   6:   port    = each.value
     │ var.port is 80
The port number must be a non-privileged port between 1024 and 65535 (inclusive).
This was checked by the validation rule at ../modules/service_config/variables.tf:16,3-13.   <- the RULE (module)
```
Write the rule once in the module, and every caller is protected.

---

## 5. Module sources

| Source | Example | `version` argument? |
|---|---|---|
| Local path | `"../modules/service_config"` (must start with `./` or `../`) | no |
| Terraform Registry | `"hashicorp/dir/template"` = NAMESPACE/NAME/PROVIDER | **yes** |
| Private registry (HCP Terraform) | `"app.terraform.io/my-org/vpc/aws"` | yes |
| GitHub | `"github.com/user/repo//path"` | no, use `?ref=` |
| Generic Git | `"git::https://github.com/Samad-Ullah/Hashicorp_Terraform.git//08-modules/modules/service_config?ref=service-config-v1.0.0"` | no, use `?ref=` |
| S3 / GCS / HTTP archive | `"s3::https://..."` | no |

- **`version` only works with registry sources.** For git, pin with `?ref=<tag>`.
- `//` separates the **repository** from the **subfolder** inside it.
- Local paths are used in place (nothing copied). Remote modules are downloaded into `.terraform/modules/`,
  and recorded in `.terraform/modules/modules.json`.
- **A git source clones the whole repository** (568K, all my labs), then uses the subfolder:
  `'Dir': '.terraform/modules/service/08-modules/modules/service_config'`.
  A registry module downloads the module's own repo (284K). So one module per repo (or a registry) keeps downloads lean.
- Changing a module's **source** (with the same code) never changes infrastructure: plan = No changes.

---

## 6. Versioning and the breaking change

**SemVer:** MAJOR.MINOR.PATCH
| Bump | When | Example |
|---|---|---|
| MAJOR (2.0.0) | breaking: callers must change their code | rename/remove an input |
| MINOR (1.1.0) | new feature, compatible | add an optional input |
| PATCH (1.0.1) | bug fix, compatible | fix a typo |

What I did:
1. Committed the module, `git tag service-config-v1.0.0`, pushed the tag. A tag = a permanent name for one commit.
2. v2: renamed input `db_host` -> `database_host`, tagged `service-config-v2.0.0`.
3. `app/` stayed on `?ref=service-config-v1.0.0` and was **not affected** (plan = No changes).
4. `payments/` uses `?ref=service-config-v2.0.0` with `database_host`.
   **Two callers, same module, different versions.**
5. Switching `app/` to v2 without changing inputs:
   ```
   Error: Unsupported argument
     on main.tf line 7, in module "service":
      7:   db_host = "db.shopcart.internal"
   An argument named "db_host" is not expected here.
   ```
   (Without the line you'd get `Missing required argument "database_host"`.) It failed at `init`, before anything was planned.
6. Proper upgrade = change the ref **and** rename the input in the same commit, then plan = No changes.

**init and modules:**
- After changing a module's `source`/`ref`, run `terraform init`. Plain `init` re-downloads it.
  If you run `plan` first, you get `Error: Module source has changed`.
- `terraform init -upgrade`: picks the newest version allowed by a `version` constraint (and provider constraints),
  and **forces modules to be re-downloaded**.
- **Stale cache:** after switching v2 -> v1, `modules.json` said v1 but the files on disk were still v2,
  so `init` kept failing with the v2 error. Fix: `terraform init -upgrade`, or `rm -rf .terraform/modules && terraform init`.
  `.terraform/` is a cache, so never commit it.

---

## 7. Registry module (hashicorp/dir/template)

```hcl
module "templates" {
  source  = "hashicorp/dir/template"
  version = "~> 1.0"

  base_dir = "${path.module}/templates"
  template_vars = {
    app      = "shopcart"
    env      = "dev"
    services = join(", ", keys(var.services))
  }
}

resource "local_file" "rendered" {
  for_each = module.templates.files              # { "motd.txt" = { content = "...", ... } }

  filename = "${path.root}/out/rendered/${each.key}"
  content  = each.value.content
}
```
- `init`: `Downloading registry.terraform.io/hashicorp/dir/template 1.0.2`. `~> 1.0` allows any 1.x,
  so it picked the newest 1.x. A 2.0.0 would never be picked automatically. **Always pin a version.**
- The module renders `*.tmpl` files (`motd.txt.tmpl` -> `motd.txt`) but creates no files itself.
  A resource must use its `files` output.
- The template file must be inside `base_dir` (`templates/`). In the wrong folder, the module renders nothing.
- Result:
  ```
  welcome to shopcart!
  Environment: dev
  Services: api, web, worker      <- keys() of a map are sorted alphabetically
  ```

---

## 8. Refactoring into a module with `moved`

Moved `local_file.service_index` (root) into a new module `modules/service_index`:
```hcl
module "index_generator" {
  source = "../modules/service_index"
  urls   = [for name, svc in module.service : svc.url]
}

moved {
  from = local_file.service_index
  to   = module.index_generator.local_file.this
}
```
-> plan: `Plan: 0 to add, 0 to change, 0 to destroy.` (a rename, not a rebuild). `apply` writes the new address to state.
Without `moved`: `1 to add, 1 to destroy`. Moving resources into or out of modules **always** changes the address.

---

## Exam traps
1. Every folder is a module. Root = where you run Terraform.
2. Child modules only see their inputs. The root only sees the child's outputs (`module.<name>.<output>`).
3. Child modules inherit providers. Don't put `provider` blocks in a child module.
4. `version` only works for **registry** sources. Git uses `?ref=`.
5. Registry format: `NAMESPACE/NAME/PROVIDER`. Private registry adds a hostname.
6. New or changed module source -> `terraform init`. `init -upgrade` = newest allowed version + re-download.
7. Modules are downloaded into `.terraform/modules/`. Local paths are not copied.
8. `module` blocks support `for_each`, `count`, `depends_on`, and `providers`.
9. Renaming a module call, or moving resources into a module, changes addresses -> use `moved`.
10. MAJOR version = breaking change. Pin versions so callers upgrade when they choose.
