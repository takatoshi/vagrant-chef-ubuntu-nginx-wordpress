#
# Cookbook Name:: nginx
# Recipe:: default
#
# Copyright 2014, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#
execute "apt-get update" do
  command "apt-get update"
end

packages = %w{build-essential zlib1g-dev libpcre3 libpcre3-dev unzip libsp-gxmlcpp-dev libgd2-xpm-dev libgeoip-dev libssl-dev}
packages.each do |pkg|
  package pkg do
    action :install
  end
end

directory "/usr/share/nginx" do
  recursive true
end

bash "Download ngx_pagespeed" do
  cwd "/usr/share/nginx"
  code <<-EOH
  wget https://github.com/pagespeed/ngx_pagespeed/archive/v1.7.30.2-beta.zip
  unzip v1.7.30.2-beta.zip
  cd ngx_pagespeed-1.7.30.2-beta/
  wget https://dl.google.com/dl/page-speed/psol/1.7.30.2.tar.gz
  tar -xzvf 1.7.30.2.tar.gz
  EOH
  not_if { ::Dir.exists?("/usr/share/nginx/ngx_pagespeed-1.7.30.2-beta") }
end

bash "Download ngx_cache_purge" do
  cwd "/usr/share/nginx"
  code <<-EOH
  wget http://labs.frickle.com/files/ngx_cache_purge-2.1.tar.gz
  tar -xzvf ngx_cache_purge-2.1.tar.gz
  EOH
  not_if { ::Dir.exists?("/usr/share/nginx/ngx_cache_purge-2.1") }
end

bash "Download and build nginx" do
  cwd "/usr/share/nginx"
  code <<-EOH
  wget http://nginx.org/download/nginx-1.4.4.tar.gz
  tar -xvzf nginx-1.4.4.tar.gz
  cd nginx-1.4.4/
  ./configure --prefix=/etc/nginx \
  --conf-path=/etc/nginx/nginx.conf \
  --error-log-path=/var/log/nginx/error.log \
  --http-client-body-temp-path=/var/lib/nginx/body \
  --http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
  --http-log-path=/var/log/nginx/access.log \
  --http-proxy-temp-path=/var/lib/nginx/proxy \
  --http-scgi-temp-path=/var/lib/nginx/scgi \
  --http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
  --lock-path=/var/lock/nginx.lock \
  --pid-path=/var/run/nginx.pid \
  --with-debug \
  --with-http_addition_module \
  --with-http_dav_module \
  --with-http_geoip_module \
  --with-http_gzip_static_module \
  --with-http_image_filter_module \
  --with-http_realip_module \
  --with-http_stub_status_module \
  --with-http_ssl_module \
  --with-http_sub_module \
  --with-http_xslt_module \
  --with-ipv6 \
  --with-sha1=/usr/include/openssl \
  --with-md5=/usr/include/openssl \
  --with-mail \
  --with-mail_ssl_module \
  --add-module=/usr/share/nginx/ngx_pagespeed-1.7.30.2-beta \
  --add-module=/usr/share/nginx/ngx_cache_purge-2.1
  make
  make install
  EOH
  not_if { ::Dir.exists?("/usr/share/nginx/nginx-1.4.4") }
end

link "/usr/sbin/nginx" do
  to "/etc/nginx/sbin/nginx"
end


directories = %w{/etc/nginx/conf.d /etc/nginx/sites-available /etc/nginx/sites-enabled}
directories.each do |dir|
  directory dir do
    recursive true
  end
end

directory "/var/lib/nginx/body" do
  owner "www-data"
  group "root"
  mode 00700
  recursive true
end

template "/etc/nginx/nginx.conf" do
  source "nginx.conf"
  owner "root"
  group "root"
  mode 00644
end

template "/etc/nginx/sites-available/default" do
  source "sites-available.default"
  owner "root"
  group "root"
  mode 00644
end

link "/etc/nginx/sites-enabled/default" do
  to "/etc/nginx/sites-available/default"
  link_type :symbolic
end

template "/etc/init.d/nginx" do
  source "nginx.init"
  owner "root"
  group "root"
  mode 00755
end

service "nginx" do
  supports [:restart, :reload, :status]
  action [:start, :enable]
end
