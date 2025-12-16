#requires -Version 5.1

<#!
Deploy the Vagrant + Docker demo in one go on Windows PowerShell.
- Starts all VMs
- Prepares Infra (bind9, hosts entries)
- Prepares Web (Docker, docker-compose, nginx config, app upload)
- Runs docker-compose
After completion:
  HTTP  -> http://localhost:8081
  HTTPS -> https://localhost:8444 (self-signed cert)
!>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Command([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name. Please install it and retry."
  }
}

function Invoke-Vagrant([string]$Args) {
  Write-Host "→ vagrant $Args" -ForegroundColor Cyan
  & vagrant $Args
}

function Invoke-SSH([string]$machine, [string]$cmd) {
  Write-Host "→ [$machine] $cmd" -ForegroundColor Yellow
  & vagrant ssh $machine -c $cmd
}

# 0) Pre-flight
Assert-Command 'vagrant'

# 1) Boot all machines
Invoke-Vagrant 'up'

# 2) Infra node: install bind9 and set /etc/hosts for simple name resolution
$infraScript = @'
set -e
sudo apt-get update -y
sudo apt-get install -y bind9
# Ensure bind9 enabled and started
sudo systemctl enable --now bind9 || true
# Hosts entries for convenience
sudo bash -lc "grep -q '^192.168.56.10\s\+admin' /etc/hosts || echo '192.168.56.10\tadmin' | sudo tee -a /etc/hosts >/dev/null"
sudo bash -lc "grep -q '^192.168.56.20\s\+web' /etc/hosts || echo '192.168.56.20\tweb' | sudo tee -a /etc/hosts >/dev/null"
sudo bash -lc "grep -q '^192.168.56.30\s\+infra' /etc/hosts || echo '192.168.56.30\tinfra' | sudo tee -a /etc/hosts >/dev/null"
sudo systemctl restart bind9 || true
'@

Invoke-SSH infra $infraScript

# 3) Web node: install Docker, docker-compose, nginx, prepare app dir
$webScriptBeforeUpload = @'
set -e
sudo apt-get update -y
sudo apt-get install -y docker.io docker-compose nginx curl
sudo systemctl enable --now docker
# Add vagrant to docker group (idempotent)
sudo usermod -aG docker vagrant || true
# Stop and disable host nginx (we'll run nginx in Docker)
sudo systemctl stop nginx || true
sudo systemctl disable nginx || true
# Ensure app dir
sudo -u vagrant mkdir -p /home/vagrant/app
'@

Invoke-SSH web $webScriptBeforeUpload

# 3.1) Upload app folder from host to web VM
Write-Host "→ Uploading ./app to web:/home/vagrant/app" -ForegroundColor Cyan
& vagrant upload "$(Resolve-Path ./app)" "/home/vagrant/app" web | Out-Null
# Fix ownership
Invoke-SSH web 'sudo chown -R vagrant:vagrant /home/vagrant/app'

# 3.2) HTTPS assets and nginx default.conf inside app
$webScriptAfterUpload = @'
set -e
# Ensure certs directory
sudo -u vagrant mkdir -p /home/vagrant/app/certs
# Generate self-signed cert if missing
if [ ! -f /home/vagrant/app/certs/server.crt ]; then
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /home/vagrant/app/certs/server.key \
    -out /home/vagrant/app/certs/server.crt \
    -subj "/C=FR/ST=Nouvelle-Aquitaine/L=Bordeaux/O=FilRouge/CN=web"
fi
# Write default.conf
sudo bash -lc "cat > /home/vagrant/app/default.conf <<'EOF'
server {
    listen 80;
    server_name localhost;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name localhost;

    ssl_certificate /etc/nginx/certs/server.crt;
    ssl_certificate_key /etc/nginx/certs/server.key;

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}
EOF"
# Compose v1/v2 compatibility symlink
if [ ! -e /usr/local/bin/docker-compose ] && [ -x /usr/bin/docker-compose ]; then
  sudo ln -sf /usr/bin/docker-compose /usr/local/bin/docker-compose || true
fi
if [ ! -e /usr/local/bin/docker-compose ] && [ -x /usr/libexec/docker/cli-plugins/docker-compose ]; then
  sudo ln -sf /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose || true
fi
'@

Invoke-SSH web $webScriptAfterUpload

# 3.3) Run docker compose
$composeCmd = "bash -lc 'cd /home/vagrant/app && (command -v docker-compose && docker-compose version >/dev/null 2>&1 && docker-compose up -d) || docker compose up -d'"
Invoke-SSH web $composeCmd

# 4) Final friendly output
Write-Host "\n✅ Deployment finished. Access the app here:" -ForegroundColor Green
Write-Host "  - HTTP : http://localhost:8081" -ForegroundColor Green
Write-Host "  - HTTPS: https://localhost:8444 (self-signed)" -ForegroundColor Green
