{
  local net = (import 'net.libsonnet'),
  local baseServices = (import 'baseServices.libsonnet'),
  local compose(name, subnet) = {
    version: '3.8',
    'x-name': name,
    services: baseServices(name, subnet),
    networks: {
      macvlan: {
        driver: 'macvlan',
        driver_opts: {
          parent: 'eth0',

        },
        ipam: {
          config: [
            {
              subnet: '%s.0.0/16' % net.prefix,
              gateway: '%s.0.1' % net.prefix,
            },
          ],
        },
      },
    },
  },

  local servers = {
    rpi01: compose('rpi01', 101) + {
      services+: {
        pihole: {
          image: 'pihole/pihole:v5.2',
          container_name: 'pihole',
          volumes: [
            './etc-pihole/:/etc/pihole/',
            './etc-dnsmasq.d/:/etc/dnsmasq.d/',
          ],
          environment: [
            'ServerIP=%s' % net.ip(101, 16),
            'A=b',
          ],
          env_file: '.pihole',
          restart: 'unless-stopped',
          networks: net.networks(101, 16),
          labels: {},
        },
        caddy: {
          image: 'caddy:2.2.1-alpine',
          container_name: 'caddy',
          restart: 'unless-stopped',
          networks: net.networks(101, 17),
          labels: {},
        },
      },
    },
    rpi02: compose('rpi02', 102) + {
      services+: {
        prometheus: {
          image: 'prom/prometheus:v2.23.0',
          container_name: 'prom',
          volumes: [
            './prometheus.yml:/etc/prometheus/prometheus.yml:ro',
            './prometheus-data:/prometheus',
          ],
          command: [
            '--config.file=/etc/prometheus/prometheus.yml',
            '--storage.tsdb.path=/prometheus',
          ],
          dns: [
            '10.10.101.16',
          ],
          labels: {},
          networks: net.networks(102, 16),
          restart: 'unless-stopped',
        },
      },
    },
  },

  local aRecords = std.flattenArrays(std.map(
    function(v)
      local srv = v['x-name'];
      std.map(function(svc) 'address=/%s.%s/%s' % [svc.container_name, srv, svc.networks.macvlan.ipv4_address], std.objectValues(v.services)),
    std.objectValues(servers)
  )) + std.map(function(v) 'address=/rpi0%d/10.10.10%d.0' % [v,v],[1,2]),

  local srvRecords = std.map(
    function(v) (
      local srv = v['x-name'];
      std.map(function(svc) (
        if std.objectHas(svc.labels, 'metrics.port') then
          'srv-host=_metrics._tcp.craig.local,%s.%s,%s' % [svc.container_name, srv, svc.labels['metrics.port']]
        else ''
      ), std.objectValues(v.services))
    ), std.objectValues(servers)
  ),

  'rpi01/docker-compose.yaml': std.manifestYamlDoc(servers.rpi01, true),
  'rpi01/etc-dnsmasq.d/02-dns-a.conf': std.join('\n', aRecords),
  'rpi01/etc-dnsmasq.d/03-dns-srv.conf': std.join('\n', std.flattenArrays(srvRecords)),
  'rpi02/docker-compose.yaml': std.manifestYamlDoc(servers.rpi02, true),
  'rpi02/prometheus.yml': std.manifestYamlDoc((import 'promconfig.libsonnet'), true),


}
