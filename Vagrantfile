#!/usr/bin/env ruby

# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant.configure("2") do |config|

  config.vm.box = "centos/7"
  # edir 9.1 necesita redhat 7.5
  config.vm.box_version = "1809.01"
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
    app.vm.hostname = "ac.lab"
    app.vm.network :private_network, ip: "10.0.1.4"
  end
  config.vm.define "idp" do |app|
    app.vm.hostname = "idp.lab"
    app.vm.network :private_network, ip: "10.0.1.5"
  end
  config.vm.define "ag" do |app|
    app.vm.hostname = "ag.lab"
    app.vm.network :private_network, ip: "10.0.1.6"
  end

  config.vm.provision "ansible" do | ansible|
    ansible.playbook="ansible/main.yml"
    ansible.verbose = true
  end
  # config.vm.provision "shell", inline: <<-SHELL
  #   apt-get update
  #   apt-get install -y apache2
  # SHELL
end

