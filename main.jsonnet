{
  local net = (import 'net.libsonnet'),
  local baseServices = (import 'baseServices.libsonnet'),
  local images = (import 'images.libsonnet'),

  local compose(name, ip) = {
    version: '3.8',
    'x-name': name,
    'x-ip': ip,
    services: baseServices(name),
  },

  local servers0 = {
    rpi01: compose('rpi01', '10.10.101.0') + {
      services+: {
        pihole: {
          image: images.pihole,
          volumes: [
            './etc-pihole/:/etc/pihole/',
            './etc-dnsmasq.d/:/etc/dnsmasq.d/',
          ],
          environment: [
            'ServerIP=10.10.101.0',
            'A=b',
          ],
          env_file: '.pihole',
          ports: [
            '53:53/tcp',
            '53:53/udp',
            '67:67/udp',
            '80:80/tcp',
            '443:443/tcp',
          ],
        },
        caddy: {
          image: images.caddy,
          volumes: [
            './Caddyfile:/etc/caddy/Caddyfile',
          ],
          environment: {
            CADDYFILE_HASH: std.md5(importstr 'output/rpi01/Caddyfile'),
          },
          ports: [
            '81:80',
            '444:443',
            '2019:2019',
          ],
        },
        duckdns: {
          image: images.duckdns,
          env_file: '.duckdns',
        },
        unifi: {
          image: images.unifi,
          network_mode: 'host',
          volumes: [
            './unifi:/config',
          ],
          environment: [
            'MEM_LIMIT=1024M',
          ],
        },
      },
    },
    rpi02: compose('rpi02', '10.10.102.0') + {
      services+: {
        prometheus: {
          image: images.prometheus,
          container_name: 'prom',
          volumes: [
            './prometheus.yml:/etc/prometheus/prometheus.yml:ro',
            './prometheus-data:/prometheus',
          ],
          command: [
            '--config.file=/etc/prometheus/prometheus.yml',
            '--storage.tsdb.path=/prometheus',
          ],
          ports: [
            '9090:9090',
          ],
          labels: {
            'metrics.port': '9090',
          },
        },
        grafana: {
          image: images.grafana,
          ports: [
            '3000:3000',
          ],
        },
      },

    },
  },

  // apply defaults to all services
  local servers = std.mapWithKey(function(k, v) v {
    services: std.mapWithKey(function(k, svc) svc {
      restart: 'unless-stopped',
      labels+: {},
      container_name: if std.objectHas(svc, 'container_name') then svc.container_name else k,
    }, v.services),
  }, servers0),

  // extract a 'container.host' A record for every container
  local aRecords = std.flattenArrays(std.map(
    function(v)
      local srv = v['x-name'];
      local ip = v['x-ip'];
      std.map(function(svc) 'address=/%s.%s/%s' % [svc.container_name, srv, ip], std.objectValues(v.services)),
    std.objectValues(servers)
  )) + std.map(function(v) 'address=/rpi0%d/10.10.10%d.0' % [v, v], [1, 2]),

  // extrace an SRV record for each container labeles as a prom exporter
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
