#!/usr/bin/env ruby

# -*- mode: ruby -*-
# vi: set ft=ruby :
#
require 'yaml'
settings = YAML.load_file './variables.yml'


Vagrant.configure("2") do |config|

  config.vm.box = "centos/7"
  # edir 9.1 necesita redhat 7.5
  #config.vm.box_version = "1809.01"
  # evito insertar un key por machine
  # en cambio utiliza un key global
  config.ssh.insert_key=false
  config.vm.synced_folder ".","/vagrant", disabled:true

  config.vm.provider "virtualbox" do |vb|
    #vb.gui = true
    vb.memory = "2048"
    vb.linked_clone =true
  end

  # app 1 config
  config.vm.define "ac" do |app|
    app.vm.hostname = settings['ac_fqdn']
    app.vm.network :private_network, ip: settings['ac_ip_address'], nic_type: "82540EM"
  end
  config.vm.define "idp" do |app|
    app.vm.hostname = settings['ids_fqdn']
    app.vm.network :private_network, ip: settings['ids_ip_address'], nic_type: "82540EM"
  end
  config.vm.define "ag" do |app|
    app.vm.hostname = settings['ag_fqdn']
    app.vm.network :private_network, ip: settings['ag_ip_address'], nic_type: "82540EM"
  end

  config.vm.provision "ansible" do | ansible|
    ansible.playbook="ansible/main.yml"
    ansible.verbose = "true"
    ansible.extra_vars = { ansible_python_interpreter:"/usr/bin/python2" }
    # ansible.verbose = true
  end
  # config.vm.provision "shell", inline: <<-SHELL
  #   apt-get update
  #   apt-get install -y apache2
  # SHELL
end

