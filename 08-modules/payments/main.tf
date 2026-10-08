module "service" {
  source = "git::https://github.com/Samad-Ullah/Hashicorp_Terraform.git//08-modules/modules/service_config?ref=service-config-v2.0.0"

  name          = "payments"
  environment   = "prod"
  port          = 8443
  database_host = "db.payments.internal"
}
