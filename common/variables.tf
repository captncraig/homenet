variable "host" {
  type = string
}

variable "docker_host" {
  type = string
}

variable "ip" {
  type = string
}

variable "gcloud_token" {
  type      = string
  sensitive = true
}
