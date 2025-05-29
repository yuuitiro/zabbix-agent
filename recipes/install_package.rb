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
  if platform?('ubuntu') && node['platform_version'].to_f >= 18.04
    # ues signed_by for Ubuntu 20.04 and later
    keyring_asc = "/etc/apt/keyrings/zabbix.asc"
    keyring_gpg = "/etc/apt/keyrings/zabbix.gpg"

    directory '/etc/apt/keyrings' do
      owner 'root'
      group 'root'
      mode '0755'
      action :create
    end

    remote_file keyring_asc do
      source node['zabbix']['agent']['package']['repo_key']
      owner 'root'
      group 'root'
      mode '0644'
      action :create_if_missing
      not_if { ::File.exist?(keyring_gpg) }
      notifies :run, 'execute[dearmor_zabbix_key]', :immediately
    end

    execute 'dearmor_zabbix_key' do
      command "gpg --batch --yes --dearmor -o #{keyring_gpg} #{keyring_asc}"
      action :nothing
    end

    apt_repository 'zabbix' do
      uri node['zabbix']['agent']['package']['repo_uri']
      components ['main']
      key nil
      signed_by keyring_gpg
      action :add
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
