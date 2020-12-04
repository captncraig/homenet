{
  scrape_configs: [
    {
      job_name: 'docker',
      scrape_interval: '15s',
      relabel_configs:[
          {
              source_labels: ['__meta_dns_srv_record_target'],
              regex: '([a-z]+).*',
              replacement: '${1}',
              target_label: 'container',
          },
          {
              source_labels: ['__meta_dns_srv_record_target'],
              regex: '([a-z]+).([a-z0-9]+).*',
              replacement: '${2}',
              target_label: 'instance',
          },
      ],
      dns_sd_configs: [
        {
          names: ['_metrics._tcp.craig.local'],
        },
      ],
    },
  ],
}
