check "health" {
  data "local_file" "health" {
    filename = "${path.module}/health.txt"
  }

  assert {
    condition     = trimspace(data.local_file.health.content) == "OK"
    error_message = "Health check failed: The content of health.txt is not 'OK'."
  }
}
