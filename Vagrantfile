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
    # 리포의 플레이북/스크립트를 /home/vagrant 로 동기화 (클론 후 바로 사용 가능)
    admin.vm.provision "shell", inline: <<-SHELL
      set -e
      echo "[Admin] Syncing repository files from /vagrant to /home/vagrant ..."
      sudo mkdir -p /home/vagrant
      sudo rsync -a --delete /vagrant/ /home/vagrant/
      sudo chown -R vagrant:vagrant /home/vagrant
      echo "[Admin] Done. Files available under ~vagrant (and /vagrant shared)."
    SHELL
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

    # [웹 자동 배포] Ansible 없이도 동작하도록, /vagrant/app 기반으로 Docker+Nginx 컨테이너를 자동 실행
    web.vm.provision "shell", inline: <<-SHELL
      set -e
      echo "[Web] Preparing Docker/Nginx environment..."
      sudo apt-get update -y
      sudo apt-get install -y docker.io docker-compose nginx curl || true
      sudo systemctl enable --now docker
      # Host nginx는 중지 (컨테이너로 관리)
      sudo systemctl stop nginx || true
      sudo systemctl disable nginx || true

      echo "[Web] Syncing app from /vagrant/app to /home/vagrant/app ..."
      sudo rm -rf /home/vagrant/app
      sudo mkdir -p /home/vagrant/app
      # /vagrant는 호스트 리포 공유. 없으면 스킵.
      if [ -d /vagrant/app ]; then
        sudo cp -r /vagrant/app/* /home/vagrant/app/
      fi
      sudo chown -R vagrant:vagrant /home/vagrant/app

      # HTTPS 자가서명 인증서 및 기본 nginx conf 보장
      sudo -u vagrant mkdir -p /home/vagrant/app/certs
      if [ ! -f /home/vagrant/app/certs/server.crt ]; then
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
          -keyout /home/vagrant/app/certs/server.key \
          -out /home/vagrant/app/certs/server.crt \
          -subj "/C=FR/ST=Nouvelle-Aquitaine/L=Bordeaux/O=FilRouge/CN=web"
      fi
      if [ ! -f /home/vagrant/app/default.conf ]; then
        sudo bash -lc "cat > /home/vagrant/app/default.conf <<'EOF'
server { listen 80; server_name localhost; return 301 https://$host$request_uri; }
server {
  listen 443 ssl;
  server_name localhost;
  ssl_certificate /etc/nginx/certs/server.crt;
  ssl_certificate_key /etc/nginx/certs/server.key;
  location / { root /usr/share/nginx/html; index index.html; }
}
EOF"
      fi

      # docker compose v1/v2 호환 심볼릭 링크
      if [ ! -e /usr/local/bin/docker-compose ] && [ -x /usr/bin/docker-compose ]; then
        sudo ln -sf /usr/bin/docker-compose /usr/local/bin/docker-compose || true
      fi
      if [ ! -e /usr/local/bin/docker-compose ] && [ -x /usr/libexec/docker/cli-plugins/docker-compose ]; then
        sudo ln -sf /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose || true
      fi

      echo "[Web] Restarting containers via docker compose..."
      bash -lc 'cd /home/vagrant/app && (docker-compose down || docker compose down) || true'
      bash -lc 'cd /home/vagrant/app && (command -v docker-compose && docker-compose up -d --force-recreate) || docker compose up -d --force-recreate'
      echo "[Web] Done. Access: http://localhost:8081, https://localhost:8444"
    SHELL
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