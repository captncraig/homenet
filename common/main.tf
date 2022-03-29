terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "2.16.0"
    }
  }
}

provider "docker" {
  host = var.docker_host
}

resource "docker_network" "private_network" {
  name = "internal_net"
}

resource "docker_container" "rpi_exporter" {
  name  = "rpi_exporter"
  image = "carlosedp/arm_exporter:latest"
  labels {
    label = "prometheus-job"
    value = "rpi-exporter"
  }
  ports {
    internal = 9243
    external = 9243
    ip = "127.0.0.1"
  }
  lifecycle { ignore_changes = [image] }
  networks_advanced {
    name = "internal_net"
  }
}

resource "null_resource" "agent_config" {
  triggers = {
    bar = data.local_file.agentcfg.content
  }
  connection {
    type = "ssh"
    user = "ubuntu"
    host = var.ip
  }
  provisioner "file" {
    content     = templatefile("${path.module}/agent-config.yaml", { uname = "18238", password = var.gcloud_token, host=var.host })
    destination = "/home/ubuntu/agent-config.yaml"
  }
}

data "local_file" "agentcfg" {
  filename = "${path.module}/agent-config.yaml"
}

resource "docker_container" "agent" {
  depends_on = [null_resource.agent_config]
  name       = "agent"
  image      = "grafana/agent:main-80dace9"

  lifecycle { ignore_changes = [image] }
  networks_advanced {
    name = "internal_net"
  }
  command = ["--config.file=/etc/agent/agent.yaml", "--prometheus.wal-directory=/etc/agent/data", "--config.enable-read-api"]
  ports {
    internal = 80
    external = 12345
  }
  volumes {
    container_path = "/etc/agent/agent.yaml"
    host_path      = "/home/ubuntu/agent-config.yaml"
    read_only      = false
  }
  volumes {
    container_path = "/var/run/docker.sock"
    host_path      = "/var/run/docker.sock"
    read_only      = false
  }
  volumes {
    container_path = "/positions"
    host_path      = "/home/ubuntu/agent/positions"
    read_only      = false
  }
  volumes {
    container_path = "/etc/agent/data"
    host_path      = "/home/ubuntu/agent/wal"
    read_only      = false
  }
  volumes {
    container_path = "/var/lib/docker/containers"
    host_path      = "/var/lib/docker/containers"
    read_only      = true
  }
  volumes {
    container_path = "/host/root"
    host_path      = "/"
    read_only      = true
  }
  volumes {
    container_path = "/host/sys"
    host_path      = "/sys"
    read_only      = true
  }
  volumes {
    container_path = "/host/proc"
    host_path      = "/proc"
    read_only      = true
  }
 
}


