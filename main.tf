terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "2.16.0"
    }
  }
}

provider "docker" {
  host  = "ssh://ubuntu@10.10.101.0:22"
  alias = "rpi01"
}

module "common01" {
  source       = "./common"
  host         = "rpi01"
  docker_host  = "ssh://ubuntu@10.10.101.0:22"
  ip           = "10.10.101.0"
  gcloud_token = var.gcloud_token
}

provider "docker" {
  host  = "ssh://ubuntu@10.10.201.0:22"
  alias = "rpi02"
}

module "common02" {
  source       = "./common"
  host         = "rpi02"
  docker_host  = "ssh://ubuntu@10.10.201.0:22"
  ip           = "10.10.201.0"
  gcloud_token = var.gcloud_token
}


provider "docker" {
  host  = "ssh://ubuntu@10.10.202.0:22"
  alias = "rpi03"
}

module "common03" {
  source       = "./common"
  host         = "rpi03"
  docker_host  = "ssh://ubuntu@10.10.202.0:22"
  ip           = "10.10.202.0"
  gcloud_token = var.gcloud_token
}


resource "docker_container" "duckdns" {
  name     = "duckdns"
  image    = "linuxserver/duckdns:version-efa43786"
  provider = docker.rpi01
  env      = ["SUBDOMAINS=captnzappo", "TOKEN=${var.duck_token}"]
  lifecycle { ignore_changes = [image] }
}

resource "docker_container" "unifi" {
  name         = "unifi"
  image        = "linuxserver/unifi-controller:version-6.0.41"
  provider     = docker.rpi01
  env          = ["MEM_LIMIT=1024M"]
  network_mode = "host"
  volumes {
    container_path = "/config"
    host_path      = "/home/ubuntu/unifi"
    read_only      = false
  }
  lifecycle { ignore_changes = [image] }
}
