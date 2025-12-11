# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Ubuntu 22.04 LTS (Jammy Jellyfish) 박스 사용
  config.vm.box = "ubuntu/jammy64"
  config.vm.box_check_update = false
  
  # 부팅 시간 초과를 600초(10분)로 늘려 불안정한 환경에 대비합니다.
  config.vm.boot_timeout = 600

  # [1] Admin/Bastion Node (192.168.56.10)
  config.vm.define "admin" do |admin|
    admin.vm.hostname = "admin"
    admin.vm.network "private_network", ip: "192.168.56.10"
    admin.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.name = "FR_Admin"
    end
    # SSH 키 생성을 위한 스크립트 실행
    admin.vm.provision "shell", path: "scripts/setup_ssh.sh"
  end

  # [2] Web/App Node (192.168.56.20)
  config.vm.define "web" do |web|
    web.vm.hostname = "web"
    web.vm.network "private_network", ip: "192.168.56.20"
    web.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = 2
      vb.name = "FR_Web"
    end
    # 포트 포워딩: HTTP는 8081, HTTPS는 8444 사용 (충돌 방지)
    web.vm.network "forwarded_port", guest: 80, host: 8081
    web.vm.network "forwarded_port", guest: 443, host: 8444
  end

  # [3] Infra/DNS Node (192.168.56.30)
  config.vm.define "infra" do |infra|
    infra.vm.hostname = "infra"
    infra.vm.network "private_network", ip: "192.168.56.30"
    infra.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.name = "FR_Infra"
    end
  end
end