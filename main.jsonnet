{
  local net = (import 'net.libsonnet'),
  local baseServices = (import 'baseServices.libsonnet'),
  local images = (import 'images.libsonnet'),

  local compose(name, ip) = {
    version: '3.8',
    'x-name': name,
    'x-ip': ip,
    services: baseServices(name),
    // networks: {
    //   macvlan: {
    //     driver: 'macvlan',
    //     driver_opts: {
    //       parent: 'eth0',
    //     },
    //     ipam: {
    //       config: [
    //         {
    //           subnet: '10.10.0.0/16',
    //           gateway: '10.10.0.1',
    //         },
    //       ],
    //     },
    //   },
    // },
  },

  local servers0 = {
    rpi01: compose('rpi01', '10.10.101.0') + {
      services+: {
        pihole: {
          image: images.pihole,
          container_name: 'pihole',
          volumes: [
            './etc-pihole/:/etc/pihole/',
            './etc-dnsmasq.d/:/etc/dnsmasq.d/',
          ],
          environment: [
            'ServerIP=10.10.101.0',
            'A=b',
          ],
          env_file: '.pihole',
          restart: 'unless-stopped',
          ports: [
            '53:53/tcp',
            '53:53/udp',
            '67:67/udp',
            '80:80/tcp',
            '443:443/tcp',
          ],
          labels: {},
          // networks: {
          //   macvlan: {
          //     ipv4_address: '10.10.101.1',
          //   },
          // },
        },
        caddy: {
          image: images.caddy,
          container_name: 'caddy',
          restart: 'unless-stopped',
          labels: {},
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
        duck: {
          image: images.duckdns,
          container_name: 'duckdns',
          restart: 'unless-stopped',
          labels: {},
          env_file: '.duckdns',
        },
        unifi: {
          image: images.unifi,
          container_name: 'unifi',
          restart: 'unless-stopped',
          ports: [
            '3478:3478/udp',
            '10001:10001/udp',
            '8080:8080',
            '8443:8443',
            '900:1900/udp',
            '8843:8843',
            '8880:8880',
            '6789:6789',
            '5514:5514',
          ],
          labels: {},
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
          restart: 'unless-stopped',
        },
      },
    },
  },

  // apply defaults to all services
  local servers = std.mapWithKey(function(k, v) v {
    services: std.mapWithKey(function(k, svc) svc {
      //dns: ['10.10.101.0'],
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
