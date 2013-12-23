#
# Cookbook Name:: wp-install
# Recipe:: default
#
# Copyright 2013, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#
# set localtime to Japan
link "/etc/localtime" do
  to "/usr/share/zoneinfo/Japan"
  link_type :symbolic
  action :create
end

# install nginx and other package {{{
execute "apt-get update" do
  command "apt-get update"
end

packages = %w{git vim nginx mysql-server php5 php5-fpm php5-mysql php-pear php5-curl curl}
packages.each do |pkg|
  package pkg do
    action :install
  end
end

service "nginx" do
  supports [:restart, :reload, :status]
end

service "php5-fpm" do
  supports [:restart, :reload, :status]
end

service "mysql" do
  supports [:restart, :reload, :status]
end

nginxFiles = %w{nginx.conf sites-available/default}
nginxFiles.each do |file|
  template "/etc/nginx/#{file}" do
    source "nginx/#{file}.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :restart, "service[nginx]"
  end
end

template "/etc/php5/fpm/pool.d/www.conf" do
  source "php-fpm/www.conf.erb"
  owner "root"
  group "root"
  mode 00644
  notifies :restart, "service[php5-fpm]"
end

template "/etc/mysql/my.cnf" do
  source "mysql/my.cnf.erb"
  owner "root"
  group "root"
  mode 00644
  notifies :restart, "service[mysql]"
end

# script to keep gzipped file up to date
template "#{node['wp_install']['install_dir']}/gzip_generator.sh" do
  source "gzip_generator.sh.erb"
  owner node['wp_install']['user_name']
  group node['wp_install']['user_name']
  mode 00755
end

execute 'assign-root-password' do
  command "/usr/bin/mysqladmin -u root password #{node['mysql']['root_password']}"
  action :run
  only_if "/usr/bin/mysql -u root -e 'show databases;'"
end

service "nginx" do
  action [:start, :enable]
end

service "php5-fpm" do
  action [:restart]
end

service "mysql" do
  action [:restart]
end

service "apache2" do
  action :stop
end
# }}}

# wp install {{{
directory "/usr/share/wp-cli" do
  recursive true
end

remote_file File.join("/usr/share/wp-cli", 'installer.sh') do
  source 'https://raw.github.com/wp-cli/wp-cli.github.com/master/installer.sh'
  mode 0755
  action :create
end

bin = ::File.join("/usr/share/wp-cli", 'bin', 'wp')

bash 'install wp-cli' do
  code './installer.sh'
  cwd "/usr/share/wp-cli"
  environment 'INSTALL_DIR' => "/usr/share/wp-cli"
  creates bin
end

link "/usr/bin/wp" do
  to bin
end

execute "create database" do
  command "mysql -uroot -p#{node['mysql']['root_password']} -e \"create database if not exists wordpress\""
end

file "#{node['wp_install']['server_root']}/wp-config.php" do
  action :delete
  backup false
end

bash "wp core config" do
  user node['wp_install']['user_name']
  group node['wp_install']['user_name']
  cwd node['wp_install']['server_root']
  code <<-EOH
    wp core config \\
    --dbname=wordpress \\
    --dbuser=root \\
    --dbpass=#{node['mysql']['root_password']} \\
    --locale=#{node['wp_install']['language']}
  EOH
end

bash "wp core install" do
  user node['wp_install']['user_name']
  group node['wp_install']['user_name']
  cwd node['wp_install']['server_root']
  code <<-EOH
    wp core install \\
    --url=http://#{node['wp_install']['server_name']} \\
    --title=#{node['wp_install']['wp_title']} \\
    --admin_user=#{node['wp_install']['wp_admin_user']} \\
    --admin_password=#{node['wp_install']['wp_admin_pass']} \\
    --admin_email=#{node['wp_install']['wp_admin_email']}
  EOH
end
# }}}

# import wp db {{{
template "#{node['wp_install']['install_dir']}/wordpress.sql" do
  source "wordpress.sql"
  owner node['wp_install']['user_name']
  group node['wp_install']['user_name']
  mode "0600"
end

bash "wp db import" do
  code <<-EOH
  sed -i 's/#{node['wp_install']['other_hostname']}/#{node['wp_install']['server_name']}/g' #{node['wp_install']['install_dir']}/#{node['wp_install']['server_name']}/sitemap.xml
  sed -i 's/#{node['wp_install']['other_hostname']}/#{node['wp_install']['server_name']}/g' #{node['wp_install']['install_dir']}/wordpress.sql
  mysql -uroot -p#{node['mysql']['root_password']} wordpress < #{node['wp_install']['install_dir']}/wordpress.sql
  EOH
end
# }}}

execute "create gzipped file" do
  command "./gzip_generator.sh"
  cwd node['wp_install']['install_dir']
end
