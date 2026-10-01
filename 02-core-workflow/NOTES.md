# Terraform Core Workflow Notes

## 1. What does ~> 3.6 allow? What about ~> 3.6.0?

`~> 3.6` allows versions greater than or equal to 3.6 but less than 4.0.

Examples allowed:

* 3.6
* 3.7
* 3.9

It does not allow 4.0 or higher.

`~> 3.6.0` allows versions greater than or equal to 3.6.0 but less than 3.7.0.

Examples allowed:

* 3.6.0
* 3.6.1
* 3.6.5

It does not allow 3.7.0 or higher.

---

## 2. Should .terraform.lock.hcl be committed to git? Why? And what about .terraform/?

Yes, `.terraform.lock.hcl` should normally be committed to Git.

It records the provider versions selected by Terraform and their checksums. Committing it helps everyone working on the project use the same provider versions and helps make Terraform runs more consistent.

The `.terraform/` directory should not normally be committed to Git.

It contains Terraform's local working data, including downloaded provider plugins and other initialization-related files. It can be recreated by running `terraform init`.

---

## 3. Which command downloads providers? Which command formats code? Which command validates it? Which of these three need providers to be installed first?

`terraform init` downloads and installs the required providers.

`terraform fmt` formats Terraform configuration files.

`terraform validate` checks whether the Terraform configuration is syntactically valid and internally consistent.

Of these three, `terraform validate` requires the required providers to be initialized first for this configuration. That is why running `terraform validate` before `terraform init` produced the "Missing required provider" error.

`terraform fmt` does not require providers to be installed because it only formats the configuration files.

---

## 4. What's the difference between terraform plan and terraform plan -out=tfplan followed by terraform apply tfplan?

`terraform plan` calculates and displays the changes Terraform intends to make, but it does not save that exact plan for later execution.

`terraform plan -out=tfplan` creates a saved plan file named `tfplan`.

Then `terraform apply tfplan` applies the saved plan instead of creating a new interactive plan. Because the plan has already been generated and approved as a specific execution plan, Terraform does not ask for the normal "yes" confirmation.

Saved plan files should be treated carefully because they can contain sensitive information. They should not normally be committed to Git.

---

## 5. In step 8, why did local_file.app_config also get replaced?

`local_file.app_config` depends on `random_pet.app_name` because its content contains:

`random_pet.app_name.id`

For example:

`APP_NAME=${random_pet.app_name.id}`

When `terraform plan -replace=random_pet.app_name` forces the `random_pet.app_name` resource to be replaced, the generated pet name can change.

Because `local_file.app_config` uses that pet name in its content, its desired content also changes. Terraform therefore needs to replace the local file so that it contains the new generated application name.

This is an example of Terraform following a dependency between resources.

# Terraform Core Workflow Notes

## 1. What does ~> 3.6 allow? What about ~> 3.6.0?

`~> 3.6` allows versions greater than or equal to 3.6 but less than 4.0.

Examples allowed:

* 3.6
* 3.7
* 3.9

It does not allow 4.0 or higher.

`~> 3.6.0` allows versions greater than or equal to 3.6.0 but less than 3.7.0.

Examples allowed:

* 3.6.0
* 3.6.1
* 3.6.5

It does not allow 3.7.0 or higher.

---

## 2. Should .terraform.lock.hcl be committed to git? Why? And what about .terraform/?

Yes, `.terraform.lock.hcl` should normally be committed to Git.

It records the provider versions selected by Terraform and their checksums. Committing it helps everyone working on the project use the same provider versions and helps make Terraform runs more consistent.

The `.terraform/` directory should not normally be committed to Git.

It contains Terraform's local working data, including downloaded provider plugins and other initialization-related files. It can be recreated by running `terraform init`.

---

## 3. Which command downloads providers? Which command formats code? Which command validates it? Which of these three need providers to be installed first?

`terraform init` downloads and installs the required providers.

`terraform fmt` formats Terraform configuration files.

`terraform validate` checks whether the Terraform configuration is syntactically valid and internally consistent.

Of these three, `terraform validate` requires the required providers to be initialized first for this configuration. That is why running `terraform validate` before `terraform init` produced the "Missing required provider" error.

`terraform fmt` does not require providers to be installed because it only formats the configuration files.

---

## 4. What's the difference between terraform plan and terraform plan -out=tfplan followed by terraform apply tfplan?

`terraform plan` calculates and displays the changes Terraform intends to make, but it does not save that exact plan for later execution.

`terraform plan -out=tfplan` creates a saved plan file named `tfplan`.

Then `terraform apply tfplan` applies the saved plan instead of creating a new interactive plan. Because the plan has already been generated and approved as a specific execution plan, Terraform does not ask for the normal "yes" confirmation.

Saved plan files should be treated carefully because they can contain sensitive information. They should not normally be committed to Git.

---

## 5. In step 8, why did local_file.app_config also get replaced?

`local_file.app_config` depends on `random_pet.app_name` because its content contains:

`random_pet.app_name.id`

For example:

`APP_NAME=${random_pet.app_name.id}`

When `terraform plan -replace=random_pet.app_name` forces the `random_pet.app_name` resource to be replaced, the generated pet name can change.

Because `local_file.app_config` uses that pet name in its content, its desired content also changes. Terraform therefore needs to replace the local file so that it contains the new generated application name.

This is an example of Terraform following a dependency between resources.
