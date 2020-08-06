#!/usr/bin/env ruby

# -*- mode: ruby -*-
# vi: set ft=ruby :
#
require 'yaml'
settings = YAML.load_file './variables.yml'



boxes = [
    {
        :name     => "ac",
        :hostname => settings['ac_fqdn'],
        :memory   => 2048,
        :cpus     => 1,
        :network  => settings['ac_ip_address']
    },
    {
        :name     => "idp",
        :hostname => settings['ids_fqdn'],
        :memory   => 2048,
        :cpus     => 1,
        :network  => settings['ids_ip_address']
    },
    {
        :name     => "ag",
        :hostname => settings['ag_fqdn'],
        :memory   => 2048,
        :cpus     => 1,
        :network  => settings['ag_ip_address']
    },

]

Vagrant.configure("2") do |config|

  # Base Vagrant VM configuration
  config.vm.box = "centos/7"
  config.ssh.insert_key = false
  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.provider :virtualbox do |v|
    v.linked_clone = true
  end

  # Configure all VMs
  boxes.each_with_index do |box, index|
    config.vm.define box[:name] do |box_config|
      box_config.vm.hostname = box[:hostname]
      box_config.vm.network "private_network",
                            ip: box[:network]
      box_config.vm.provider "virtualbox" do |v|
        v.memory = box[:memory]
        v.cpus = box[:cpus]
      end

      # only start ansible provision after the last box
      if index == boxes.size - 1
        # PROVISIONING WITH ANSIBLE
        # ------------------------------------------------------------------------
        box_config.vm.provision "ansible" do |ansible|
          # ansible.inventory_path = "ansible/hosts.yml"
          ansible.limit = "all"
          ansible.playbook = "ansible/main.yml"
          ansible.raw_arguments = ["--private-key=~/.vagrant.d/insecure_private_key"]
        end
      end
     end
   end
end
