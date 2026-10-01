1. Variable precedence

Lowest → highest:

Default values
→ TF_VAR_ environment variables
→ terraform.tfvars
→ terraform.tfvars.json
→ *.auto.tfvars / *.auto.tfvars.json (lexical order, so z beats a)
→ -var / -var-file command-line arguments (in the order given; the last one wins)

2. Complex types

List

Ordered collection.
Duplicates allowed.

["a", "b", "a"]

Set

Unordered collection.
Duplicates removed.

["a", "b", "a"]

becomes conceptually:

{"a", "b"}


Map

A collection of values accessed by keys, where the values have the same type.

{
  dev  = true
  prod = false
}

Object

A structured value with named attributes that can have different types.

{
  engine  = "postgres"
  version = "16"
  port    = 5432
}

Tuple

An ordered collection where each position can have a specific type.

Your example:

tuple([string, number])

means:

position 0 → string
position 1 → number

For example:

["sun", 3]



3. What does sensitive = true protect you from?

It helps prevent sensitive values from being displayed normally in Terraform CLI output.

It does not:

encrypt the value in state
remove the value from state
prevent someone with access to state from seeing it
make the value inherently secure


4. Variable vs local vs output

Variable

An input to the module/configuration.

outside → variable → Terraform

Local

An internal calculated/reusable value.

variables/resources → local → Terraform configuration

A user cannot override a local from outside using -var.

Output

A value Terraform exposes after execution.

Terraform → output → user/caller



5. What does optional(number, 5432) do?

It means the object attribute is optional.

If the caller does not provide it, Terraform automatically uses:

5432

So:

port = optional(number, 5432)

means:

port may be omitted, but when omitted its value becomes 5432.




## Experiment 1 - Plan with no values

Command: terraform plan   (no tfvars files, no TF_VAR_ set)

Terraform prompted only for variables WITHOUT a default:
    var.database
    var.db_password
    var.environment

- The prompts come in ALPHABETICAL order, not the order in variables.tf
  (environment is first in the file but asked last).
- app_name, replicas, etc. were not asked for because they have defaults.
- With -input=false (as in CI), it does not prompt; it fails with
  "Error: No value for required variable" once for each missing variable.

## Experiment 2 - Precedence battle (replicas)

Sources: TF_VAR_replicas=2, terraform.tfvars=3, a.auto.tfvars=4,
z.auto.tfvars=5, -var=replicas=6. Default in variables.tf = 1.

| Run | Sources present           | REPLICAS in plan |
|-----|---------------------------|------------------|
| 1   | all five                  | 6                |
| 2   | removed -var              | 5                |
| 3   | removed z.auto.tfvars     | 4                |
| 4   | removed a.auto.tfvars     | 3                |
| 5   | removed terraform.tfvars  | 2                |
| 6   | unset TF_VAR_replicas     | 1 (default)      |

Extra checks:
- terraform.tfvars (3) + terraform.tfvars.json (7)  -> 7 (.json is loaded after)
- -var=replicas=8 -var=replicas=9                   -> 9 (last one on the CLI wins)

Conclusion (lowest -> highest):
default -> TF_VAR_ env var -> terraform.tfvars -> terraform.tfvars.json
-> *.auto.tfvars (alphabetical, so z beats a) -> -var / -var-file (last wins)

## Experiment 3 - Set with duplicates

Input:  availability_zones = ["b", "a", "b"]
Result: ["a", "b"]  -> duplicates removed, shown sorted. A set has no index,
so availability_zones[0] is not allowed.

## Experiment 4 - Wrong types

-var="replicas=three"   -> Error: Invalid value for input variable
                           "a number is required."
-var='replicas="5"'     -> SAME error!
-var="replicas=5"       -> works, REPLICAS=5
replicas = "5" in a .tfvars file -> works, REPLICAS=5

Why: for a primitive type (string/number/bool), -var takes the text after
"=" literally. -var='replicas="5"' passes the 3 characters "5" (quotes
included), which is not a number. In a .tfvars file, "5" is parsed as HCL,
so it is the string 5, and Terraform converts it to the number 5 automatically.
Lesson: Terraform converts "5" -> 5, but not "three" -> number.

## Experiment 5 - Optional vs required object attributes

database = { engine = "postgres", version = "16" }  (no port)
  -> plan shows port = 5432 (filled in by optional(number, 5432))
  -> backups = false (filled in by optional(bool, false))

database = { version = "16" }  (no engine)
  -> Error: Invalid value for input variable
     "attribute "engine" is required."

Lesson: attributes without optional() are required; optional(type, default)
fills in the default when the attribute is left out.

## Experiment 6 - Is the password in the state file?

Command:
    terraform apply -var-file=dev.tfvars
    grep -n "Sup3rS3cret" terraform.tfstate

Result:
The password appears in plain text in terraform.tfstate, at least twice:
- in the `outputs` section (db_password value)
- in the `local_sensitive_file.db_secret` resource content

Note: `grep -i password` only matched the line with the output *name*;
the value is on the next line. Search for the value itself to find every copy.
the .backup file kept the secret after destroy

Lesson:
`sensitive = true` (on variables, outputs, and even local_sensitive_file)
does NOT encrypt or remove the value from state. It only hides it in CLI output.
-> State must be protected: never commit it, use a remote backend with
   encryption and access control, and treat state as a secret.

## Experiment 7 - Which output commands show the password?

| Command                        | Password shown?                        |
|--------------------------------|----------------------------------------|
| terraform output               | No  -> db_password = <sensitive>       |
| terraform output db_password   | Yes -> "Sup3rS3cret!"                  |
| terraform output -json         | Yes -> plain text, with "sensitive": true |
| terraform output -raw db_password | Yes -> Sup3rS3cret! (no quotes)     |

Lesson:
Sensitive values are only redacted in the normal listing. Asking for an output
by name, or with -json / -raw, prints it in plain text.
That's by design: -json and -raw are used by scripts and CI pipelines.

Bonus observations:
- availability_zones ["b","a","b"] became toset(["a","b"]): a set removes
  duplicates and has no guaranteed order (shown sorted).
- common_tags shows type "object" in -json, not "map": a { } literal in locals
  is an object unless converted (tomap() or a map-typed variable).