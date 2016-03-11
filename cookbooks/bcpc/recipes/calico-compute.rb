#
# Cookbook Name:: bcpc
# Recipe:: calico-compute
#
# Copyright 2016, Bloomberg Finance L.P.
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

apt_repository "calico" do
  uri node['bcpc']['repos']['calico']
  distribution node['lsb']['codename']
  components ["main"]
  key "calico-release.key"
  notifies :run, "execute[apt-get update]", :immediately
end

# install etcd from calico repo
package "etcd" do
    action :upgrade
end

package "python-etcd" do
    action :upgrade
end

# stop etcd while we create a tmpfs datadir and write proper config
service "etcd" do
    action [:enable, :stop]
end

# TODO: make sure we need this
bash "etcd-data-dir" do
  code <<-EOH
       service etcd stop
       sleep 5
       rm -rf /var/lib/etcd/*
       mount -t tmpfs -o size=512m tmpfs /var/lib/etcd
       egrep '^tmpfs /var/lib/etcd ' /etc/fstab || echo 'tmpfs /var/lib/etcd tmpfs nodev,nosuid,noexec,nodiratime,size=512M 0 0' >> /etc/fstab
  EOH
  # not_if "grep '/var/lib/etcd' /etc/fstab"
end

# /etc/init/etcd.conf
template "/etc/init/etcd.conf" do
    source "etcd.conf.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :start, "service[etcd]", :immediately
end

service "etcd" do
    action [:enable, :start]
end

# Calico uses their own dnsmasq
# apt-get install --only-upgrade dnsmasq-base dnsmasq-utils
package "dnsmasq-base" do
    action :upgrade
end

package "dnsmasq-utils" do
    action :upgrade
end

# I think this is a no-op
#package "neutron-common" do
#    action :upgrade
#end

# this is temporary hack to make Calico work
# package "python-pip" do
#    action :upgrade
#end

# must install without dependencies
# otherwise it installs pbr version that breaks keystone
#bash "install-networking-calico" do
#    code "pip install --no-deps networking-calico"
#end

#cookbook_file "/tmp/networking-calico-1.0.0.tar.gz" do
#    source "networking-calico-1.0.0.tar.gz"
#    owner "root"
#    mode 00644
#end

#bash "install-networking-calico" do
#    code "pip install --no-deps --no-index --find-links file:///tmp/ networking-calico"
#end


package "neutron-dhcp-agent" do
    action :upgrade
end

#package "neutron-api-metadata" do
#    action :upgrade
#end

# service neutron-dhcp-agent stop
#bash "stop-neutron-dhcp-agent" do
#   code "service neutron-dhcp-agent stop"
#end

package "calico-compute" do
    action :upgrade
end

template "/etc/calico/felix.cfg" do
    source "felix.cfg.erb"
    owner "root"
    group "root"
    mode 00644
    #notifies :start, "service[etcd]", :immediately
end

bash "start-calico-felix" do
    code "service calico-felix restart"
end
