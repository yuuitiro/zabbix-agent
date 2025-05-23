# Author:: Nacer Laradji (<nacer.laradji@gmail.com>)
# Cookbook:: zabbix
# Recipe:: agent_package
#
# Copyright:: 2011, Efactures
#
# Apache 2.0
#

case node['platform_family']
when 'windows'
  include_recipe 'chocolatey'
  chocolatey_package 'zabbix-agent'
when 'debian'
  if platform?('ubuntu') && node['platform_version'].to_f >= 24.0
    directory '/etc/apt/keyrings' do
      owner 'root'
      group 'root'
      mode '0755'
      recursive true
      action :create
    end

    execute 'download-and-dearmor-zabbix-gpg-key' do
      command "curl -fsSL #{node['zabbix']['agent']['package']['repo_key']} | gpg --dearmor | tee /etc/apt/keyrings/zabbix.gpg > /dev/null"
      creates '/etc/apt/keyrings/zabbix.gpg'
      notifies :create, 'file[/etc/apt/keyrings/zabbix.gpg]', :immediately
    end

    file '/etc/apt/keyrings/zabbix.gpg' do
      owner 'root'
      group 'root'
      mode '0644'
      action :nothing
    end

    ruby_block 'wait-for-gpg-key' do
      block do
        raise "GPG key file not found at /etc/apt/keyrings/zabbix.gpg" unless ::File.exist?('/etc/apt/keyrings/zabbix.gpg')
      end
      action :run
    end

    apt_repository 'zabbix' do
      uri node['zabbix']['agent']['package']['repo_uri']
      components ['main']
      key '/etc/apt/keyrings/zabbix.gpg'
      trusted true
      subscribes :add, 'ruby_block[wait-for-gpg-key]', :immediately
    end
  else
    apt_repository 'zabbix' do
      uri node['zabbix']['agent']['package']['repo_uri']
      components ['main']
      key node['zabbix']['agent']['package']['repo_key']
    end
  end

  package 'zabbix-agent' do
    options '-o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"'
    action :upgrade
  end
when 'rhel', 'amazon', 'fedora'
  yum_repository 'zabbix' do
    repositoryid 'zabbix'
    description 'Zabbix Official Repository'
    baseurl node['zabbix']['agent']['package']['repo_uri']
    gpgkey node['zabbix']['agent']['package']['repo_key']
    sslverify false
    action :create
  end

  yum_repository 'zabbix-non-supported' do
    repositoryid 'zabbix-non-supported'
    description 'Zabbix Official Repository non-supported - $basearch'
    baseurl node['zabbix']['agent']['package']['repo_uri']
    gpgkey node['zabbix']['agent']['package']['repo_key']
    sslverify false
    action :create
  end

  package 'zabbix-agent' do
    action :upgrade
  end
end
