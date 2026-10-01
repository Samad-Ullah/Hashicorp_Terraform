locals {
  name_prefix = "${var.app_name}-${var.environment}"

  common_tags = {
    app        = var.app_name
    env        = var.environment
    managed_by = "terraform"
  }
}
