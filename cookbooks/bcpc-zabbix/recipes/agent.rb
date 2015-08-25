#
# Cookbook Name:: bcpc-zabbix
# Recipe:: agent
#
# Copyright 2015, Bloomberg Finance L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

if node['bcpc']['enabled']['monitoring']
    include_recipe 'bcpc-zabbix'

    # this script removes the old manually compiled Zabbix agent installation
    # (being a bit lazy and assuming the presence of the old agent binary signals everything
    # is still there)
    bash "clean-up-old-zabbix-agent" do
        code <<-EOH
          service zabbix-agent stop
          rm -f /tmp/zabbix_agentd.pid
          rm -f /usr/local/etc/zabbix_agent.conf
          rm -f /usr/local/etc/zabbix_agentd.conf
          rm -f /usr/local/sbin/zabbix_agent
          rm -f /usr/local/sbin/zabbix_agentd
          rm -f /usr/local/share/man/man1/zabbix_get.1
          rm -f /usr/local/share/man/man1/zabbix_sender.1
          rm -f /usr/local/share/man/man8/zabbix_agentd.8
          rm -f /usr/local/bin/zabbix_get
          rm -f /usr/local/bin/zabbix_sender
          rm -rf /usr/local/etc/zabbix_agentd.conf.d
          rm -rf /usr/local/etc/zabbix_agent.conf.d
          rm -f /tmp/zabbix-agent.tar.gz
          rm -f /etc/init/zabbix-agent.conf
        EOH
        only_if 'test -f /usr/local/sbin/zabbix_agentd'
    end

    %w{zabbix-agent zabbix-get zabbix-sender}.each do |zabbix_package|
      package zabbix_package do
        action :upgrade
      end
    end

    group "adm" do
        action :modify
        append true
        members "zabbix"
    end

    template "/etc/zabbix/zabbix_agent.conf" do
        source "zabbix_agent.conf.erb"
        owner node['bcpc']['zabbix']['user']
        group "root"
        mode 00600
        notifies :restart, "service[zabbix-agent]", :delayed
    end

    template "/etc/zabbix/zabbix_agentd.conf" do
        source "zabbix_agentd.conf.erb"
        owner node['bcpc']['zabbix']['user']
        group "root"
        mode 00600
        notifies :restart, "service[zabbix-agent]", :delayed
    end

    ruby_block "zabbix-openstack-template-lazy-wrapper" do
      block do
        template "/etc/zabbix/zabbix_agentd.d/zabbix-openstack.conf" do
          source "zabbix_openstack.conf.erb"
          owner node['bcpc']['zabbix']['user']
          group "root"
          mode 00600
          only_if { get_cached_head_node_names.include?(node['hostname']) }
          notifies :restart, "service[zabbix-agent]", :immediately
        end
      end
    end

    template "/etc/zabbix/zabbix_agentd.d/zabbix-rgw.conf" do
        source "zabbix_rgw.conf.erb"
        owner node['bcpc']['zabbix']['user']
        group "root"
        mode 00600
        variables(
          :rgw_frontend => node['bcpc']['ceph']['frontend']
        )
        only_if 'test -f /usr/bin/radosgw'
        notifies :restart, "service[zabbix-agent]", :immediately
    end

    template "/etc/zabbix/zabbix_agentd.d/userparameter_mysql.conf" do
        source "zabbix_agentd_userparameters_mysql.conf.erb"
        owner node['bcpc']['zabbix']['user']
        group "root"
        mode 00600
        only_if 'test -f /etc/mysql/debian.cnf'
        notifies :restart, "service[zabbix-agent]", :immediately
    end

    service "zabbix-agent" do
        action [:enable, :start]
        provider Chef::Provider::Service::Init::Debian
        status_command "service zabbix-agent status"
    end

    cookbook_file "/tmp/python-requests-aws_0.1.6_all.deb" do
        source "python-requests-aws_0.1.6_all.deb"
        cookbook 'bcpc-binary-files'
        owner "root"
        mode 00444
    end

    package "requests-aws" do
        provider Chef::Provider::Package::Dpkg
        source "/tmp/python-requests-aws_0.1.6_all.deb"
        action :install
    end

    ruby_block "zabbix_discover_buckets-lazy-wrapper" do
      block do
        cookbook_file "/usr/local/bin/zabbix_discover_buckets" do
          source "zabbix_discover_buckets"
          owner "root"
          mode "00755"
          only_if { get_cached_head_node_names.include?(node['hostname']) }
        end
      end
    end
end