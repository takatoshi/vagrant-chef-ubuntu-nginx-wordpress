#
# Cookbook Name:: tactosh
# Recipe:: default
#
# Copyright 2013, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#
execute "apt-get update" do
  command "apt-get update"
end

packages = %w{git vim nginx php5 php5-fpm php5-mysql php-pear php5-curl curl phpmyadmin}
packages.each do |pkg|
  package pkg do
    action :install
  end
end

service "nginx" do
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

service "nginx" do
  action [:start, :enable]
end

service "php5-fpm" do
  supports [:restart, :reload, :status]
  action [:restart]
end

service "apache2" do
  action :stop
end

link "#{node['wp_install']['server_root']}/phpmyadmin" do
  to "/usr/share/phpmyadmin"
  link_type :symbolic
  action :create
end

execute 'install wp-cli' do
  user "vagrant"
  group "vagrant"
  command 'curl https://raw.github.com/wp-cli/wp-cli.github.com/master/installer.sh | bash'
end

link "/usr/bin/wp" do
  to "/home/vagrant/.wp-cli/bin/wp"
end

file "#{node['wp_install']['server_root']}/wp-config.php" do
  action :delete
  backup false
end

bash "wp core config" do
  user "vagrant"
  group "vagrant"
  cwd node['wp_install']['server_root']
  code <<-EOH
    wp core config \\
    --dbname=wordpress \\
    --dbuser=root \\
    --dbpass=#{node['mysql']['server_root_password']}
  EOH
end

execute "create database" do
  command "mysql -uroot -p#{node['mysql']['server_root_password']} -e \"create database if not exists wordpress\""
end

bash "wp core install" do
  user "vagrant"
  group "vagrant"
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

template "#{node['wp_install']['install_dir']}/wordpress.sql" do
  source "wordpress.sql.erb"
  owner "vagrant"
  group "vagrant"
  mode "0600"
  notifies :run, "bash[wp db export]", :immediately
end

bash "wp db export" do
  code <<-EOH
  mysql -uroot -p#{node['mysql']['server_root_password']} wordpress < #{node['wp_install']['install_dir']}/wordpress.sql
  mysql -uroot -p#{node['mysql']['server_root_password']} wordpress -e "update wp_options set option_value='http://#{node['wp_install']['server_name']}' where wp_options.option_id=3;"
  mysql -uroot -p#{node['mysql']['server_root_password']} wordpress -e "update wp_options set option_value='http://#{node['wp_install']['server_name']}' where wp_options.option_id=39;"
  EOH
end
