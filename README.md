# Fil Rouge: Vagrant + Ansible + Docker Quick Deploy

This repo spins up a 3-VM lab with Vagrant and deploys a simple Nginx app via Docker on the Web node.

- admin  (192.168.56.10)
- web    (192.168.56.20) ← Nginx in Docker, serves the app
- infra  (192.168.56.30) ← Bind9 (DNS) + hosts convenience entries

Port forwarding on host:
- HTTP  : http://localhost:8081
- HTTPS : https://localhost:8444 (self-signed)

## Prerequisites
- Windows 10/11
- PowerShell 5.1+
- VirtualBox (6.x/7.x)
- Vagrant (2.3+)

> Note: Ansible playbooks are included for reference and future use, but the provided PowerShell script deploys without requiring Ansible installed on Windows.

## One‑click deploy (Windows)

Run from the repo root:

```powershell
# PowerShell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
./scripts/deploy.ps1
```

What it does:
- `vagrant up` all VMs
- Infra: install bind9 and add hosts entries
- Web: install Docker + docker-compose, stop host nginx, upload `app/`, generate self-signed certs, write `default.conf`, run `docker-( )compose up -d`

After success, open:
- HTTP  → http://localhost:8081
- HTTPS → https://localhost:8444 (accept the certificate warning)

## Project layout
- `Vagrantfile` — 3 VMs (admin, web, infra)
- `app/` — docker-compose and static site (mounted into the Nginx container)
- `*.yml` — Ansible playbooks (optional, not required by the PowerShell deploy)
- `scripts/deploy.ps1` — one‑click Windows deployment

## Troubleshooting
- If `vagrant up` fails, run `vagrant destroy -f; vagrant up` to reset the lab.
- Docker may require a re-login for the `vagrant` user to pick up the `docker` group; the script runs Docker non-interactively, so it should still work.
- If ports 8081/8444 are in use, change them in `Vagrantfile` and re-run `vagrant reload --provision` then `./scripts/deploy.ps1`.

## Next steps (optional)
- Wire Ansible to run from the `admin` VM as a controller (add inventory and key distribution).
- Add GitHub Actions to lint Ansible/YAML and validate the Compose file.
- Parameterize common settings via a `.env`.
