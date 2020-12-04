{
  prefix: '10.10',
  ip: function(base, offset) '%s.%d.%d' % [$.prefix, base, offset],
  networks: function(base, offset) {
    macvlan: {
      ipv4_address: $.ip(base, offset),
    },
  },
}
