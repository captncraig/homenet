function(name, subnet) {
  local net = (import 'net.libsonnet'),
  node_exporter: {
    image: 'prom/node-exporter:v1.0.1',
    container_name: 'nodeexporter',
    volumes: [
      '/proc:/host/proc:ro',
      '/sys:/host/sys:ro',
      '/:/rootfs:ro',
    ],
    command: [
      '--path.procfs=/host/proc',
      '--path.rootfs=/rootfs',
      '--path.sysfs=/host/sys',
      '--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc)($$|/)',
    ],
    labels: {
      'metrics.port': '9100',
    },
    restart: 'unless-stopped',
    networks: net.networks(subnet, 1),
  },
  rpi_exporter: {
    image: 'carlosedp/arm_exporter:latest',
    container_name: 'armexporter',
    restart: 'unless-stopped',
    networks: net.networks(subnet, 2),
    labels: {
      'metrics.port': '9243',
    },
  },
}
