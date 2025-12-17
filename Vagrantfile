# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Utiliser la box Ubuntu 22.04 LTS (Jammy Jellyfish)
  config.vm.box = "ubuntu/jammy64"
  config.vm.box_check_update = false
  
  # Augmenter le délai de démarrage à 600s (10 min) pour pallier des environnements instables
  config.vm.boot_timeout = 600

  # [1] Nœud Admin/Bastion (192.168.56.10)
  config.vm.define "admin" do |admin|
    admin.vm.hostname = "admin"
    admin.vm.network "private_network", ip: "192.168.56.10"
    admin.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.name = "FR_Admin"
    end
    # Exécuter le script de génération de clés SSH
    admin.vm.provision "shell", path: "scripts/setup_ssh.sh"
    # Synchroniser les fichiers du dépôt (playbooks/scripts) vers /home/vagrant (utilisable immédiatement après le clone)
    admin.vm.provision "shell", inline: <<-SHELL
      set -e
      echo "[Admin] Syncing repository files from /vagrant to /home/vagrant ..."
      sudo mkdir -p /home/vagrant
      sudo rsync -a --delete /vagrant/ /home/vagrant/
      sudo chown -R vagrant:vagrant /home/vagrant
      echo "[Admin] Done. Files available under ~vagrant (and /vagrant shared)."
    SHELL
  end

  # [2] Nœud Web/App (192.168.56.20)
  config.vm.define "web" do |web|
    web.vm.hostname = "web"
    web.vm.network "private_network", ip: "192.168.56.20"
    web.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = 2
      vb.name = "FR_Web"
    end
    # Redirection de ports : HTTP 8081, HTTPS 8444 (pour éviter les collisions)
    web.vm.network "forwarded_port", guest: 80, host: 8081
    web.vm.network "forwarded_port", guest: 443, host: 8444

    # [Déploiement Web automatique] Lancer automatiquement un conteneur Docker+Nginx basé sur /vagrant/app, sans Ansible
    web.vm.provision "shell", inline: <<-SHELL
      set -e
      echo "[Web] Preparing Docker/Nginx environment..."
      sudo apt-get update -y
      sudo apt-get install -y docker.io docker-compose nginx curl || true
      sudo systemctl enable --now docker
      # Arrêter nginx sur l'hôte (géré via conteneur)
      sudo systemctl stop nginx || true
      sudo systemctl disable nginx || true

      echo "[Web] Syncing app from /vagrant/app to /home/vagrant/app ..."
      sudo rm -rf /home/vagrant/app
      sudo mkdir -p /home/vagrant/app
      # /vagrant est le partage du dépôt hôte. Ignorer si absent.
      if [ -d /vagrant/app ]; then
        sudo cp -r /vagrant/app/* /home/vagrant/app/
      fi
      sudo chown -R vagrant:vagrant /home/vagrant/app

      # Garantir le certificat auto-signé et la configuration nginx par défaut
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

      # Lien symbolique de compatibilité pour docker compose v1/v2
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

  # [3] Nœud Infra/DNS (192.168.56.30)
  config.vm.define "infra" do |infra|
    infra.vm.hostname = "infra"
    infra.vm.network "private_network", ip: "192.168.56.30"
    infra.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.name = "FR_Infra"
    end
  end
end