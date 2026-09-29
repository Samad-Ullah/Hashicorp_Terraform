# Hashicorp_Terraform

Practice repository for learning Terraform, working towards the HashiCorp
Terraform Associate (004).

## Layout

| Folder | What it covers |
| --- | --- |
| `01Basics` | First configuration: the `local` provider, a `local_file` resource, and an output. |

## Usage

```bash
cd 01Basics
terraform init
terraform plan
terraform apply
terraform destroy
```

## Notes

`.terraform/` and `*.tfstate` are intentionally not committed. Provider binaries are
re-downloaded by `terraform init`, and state can contain secrets in plain text.
`.terraform.lock.hcl` **is** committed on purpose, so provider versions stay
reproducible.
