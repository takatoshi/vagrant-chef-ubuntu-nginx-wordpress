case node['mode']
when "live"
  default['nginx']['do_not_cache'] = 0
  default['nginx']['expire'] = "10d"
  default['nginx']['gzip'] = "on"
  default['nginx']['gzip_static'] = "on"
  default['nginx']['sendfile'] = "on"
when "debug"
  default['nginx']['do_not_cache'] = 1
  default['nginx']['expire'] = "off"
  default['nginx']['gzip'] = "off"
  default['nginx']['gzip_static'] = "off"
  default['nginx']['sendfile'] = "off"
end
