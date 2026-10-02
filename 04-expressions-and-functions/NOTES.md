# Lab Notes — Task 3: Expressions and Functions

## Part B: Experiments

### 1. Plan-only behavior of Data Sources vs Resources (REVISED)
* **Exam Reality Rule:** Running `terraform plan` NEVER modifies your filesystem or creates infrastructure assets. It is a completely non-destructive computation phase. The local `out/` folder is not created at all during a pure plan phase.
* **Data Source vs Resource Deferral:** Data sources can execute during `plan` if all input variable allocations are known. However, because our `archive_file.bundle` dynamic blocks track parameters directly bound to managed resource attributes (`local_file.nginx_conf.content`), Terraform explicitly defers evaluating the archive data execution entirely to the `apply` runtime lifecycle stage.

### 2. Behavior during `-var="environment=prod"`
* **Values that changed:** `is_prod` evaluates to `true`, `log_level` changes to `"warn"`, and `replicas` for all workflows scale up to a floor of `3` due to `max(3, s.replicas)`.
* **Nginx Configuration:** The `# DEBUG MODE` comment block safely disappears from the rendered file because the conditional `%{ if !is_prod }` evaluates to false.

### 3. Break It 1: Duplicate Naming Error
* **The Error:** `services_by_name` throws an explicit `Duplicate object key` compilation abort error because map data models strictly enforce key uniqueness constraints.
* **What still works:** `local.service_names` continues to function. The splat operator `[*]` works iteratively on lists/tuples sequentially and does not check for duplicate values.

### 4. Break It 2: Splatting a Map
* **Why it fails:** Applying a splat operator `[*]` to a map value wraps the entire map structure inside a temporary element structure block and evaluates `.port` against the root container instead of iterating individual entries. This results in an `Unsupported attribute` crash.
* **The Fix:** Evaluate utilizing `values()` inside a clean mapping lookup: `values(local.services_by_name)[*].port`. Note that this yields variables ordered alphabetically by key (`api`, `payments`, `web`, `worker`), rather than the declaration order.

### 5. Stripping Whitespace (`~`)
* **Behavior:** Removing the `~` markers introduces trailing blank empty carriage lines right inside the output text configuration. The `~` strips out unintended blank formatting loops.

### 6. Console Prediction Game

| Expression | Expected Prediction | Actual Console Result |
| :--- | :--- | :--- |
| `cidrsubnet("10.0.0.0/16", 8, 2)` | `"10.0.2.0/24"` | `"10.0.2.0/24"` |
| `flatten([["a"], ["b", ["c"]]])` | `["a", "b", "c"]` | `["a", "b", "c"]` |
| `{ for k, v in {a=1, b=2, c=3} : k => v * 10 if v > 1 }` | `{ b = 20, c = 30 }` | `{ b = 20, c = 30 }` |
| `{ for s in ["web", "api", "worker"] : length(s) => s... }` | `{ 3 = "api", 6 = "worker" }` | `{ 3 = ["web", "api"], 6 = ["worker"] }` |
| `lookup({a = 1}, "b", 0)` | `0` | `0` |
| `try(local.services_by_name["nope"].port, 80)` | `80` | `80` |
| `can(local.services_by_name["nope"])` | `false` | `false` |
| `coalesce("", "x")` | `"x"` | `"x"` |
| `element(["a", "b", "c"], 4)` | Error (Out of Bounds) | `"b"` (Automatically wraps around) |
| `["a", "b", "c"][4]` | Error (Out of Bounds) | Error (Index out of bounds) |
| `merge({a = 1, b = 2}, {b = 3})` | `{ a = 1, b = 3 }` | `{ a = 1, b = 3 }` |
| `format("%s-%03d", "web", 7)` | `"web-007"` | `"web-007"` |

---

## Part C: Core Questions

### 1. How do you make a for expression produce a list vs a map?
* Wrap the expression in square brackets `[for x in y : x]` to output a **list**.
* Wrap the expression in curly braces `{for x in y : x.key => x.value}` to output a **map**.

### 2. What does `...` do, and when do you need it?
* It is the **grouping operator (ellipsis)**. When building a map via a loop, if the evaluation produces duplicate keys, Terraform normally crashes with a duplicate key conflict. Appending `...` tells Terraform to group those values together into a nested list under that key instead of overwriting or failing.

### 3. When can you use splat `[*]`, and when must you use a `for` expression?
* Use **Splat `[*]`** as a shorthand to extract attributes out of uniform **lists or sets** (e.g., `var.list[*].id`).
* You must switch to a **`for` expression** if you need to filter items (`if`), evaluate maps, alter data formats, or work with indices.

### 4. What is a dynamic block for? What's the iterator called by default, and how do you rename it? Why does HashiCorp warn against overusing them?
* **Purpose:** It allows you to dynamically generate nested configuration blocks inside resources based on an external collection variable without copying and pasting block snippets.
* **Iterator:** By default, it takes the name of the block itself. You change it explicitly using the `iterator` argument inside the block logic.
* **Overuse warning:** They reduce readability, make debugging code complex, and abstract configuration layout schemas so severely that standard code maintenance becomes challenging.

### 5. Heredoc with `${}` vs `templatefile()`
* **Heredoc:** Best for quick, simple text templates that do not require external injection logic outside the immediate file.
* **templatefile():** Best for large configurations (like installation scripts or Nginx configs) that need to be reused across modules, maintaining separation of concerns between boilerplate templates and execution code.

### 6. `lookup()` vs `try()` vs `can()`
* `lookup(map, key, default)`: Checks a map explicitly for a clean key layout fallback. Only handles a missing map key error.
* `try(expr1, expr2, ...)`: Evaluates a series of expressions sequentially and returns the value of the first one that does not throw an initialization error. Catches any evaluation issue across nesting levels.
* `can(expr)`: Evaluates an expression and returns a strict boolean (`true` if it compiles successfully, `false` if it throws an error). Commonly implemented inside input variable validation rule blocks.

### 7. Does `terraform console` change anything in your infrastructure or state?
* **No.** It is a completely isolated read-only evaluation environment. It reads from state data to process tests, but never alters deployment configurations or cloud states.
