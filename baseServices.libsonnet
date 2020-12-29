function(name) {
  local images = (import 'images.libsonnet'),
  node_exporter: {
    image: images.node_exporter,
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
    ports: [
      "9100:9100",
    ],
    labels: {
      'metrics.port': '9100',
    },
  },
  rpi_exporter: {
    image: images.rpi_exporter,
    container_name: 'armexporter',
    ports: [
      "9243:9243",
    ],
    labels: {
      'metrics.port': '9243',
    },
  },
}
