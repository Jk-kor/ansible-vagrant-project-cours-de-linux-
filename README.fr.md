# Fil Rouge : Déploiement rapide Vagrant + Ansible + Docker


Ce dépôt lance un labo de 3 machines virtuelles avec Vagrant et déploie une application Nginx simple via Docker sur le nœud Web.

- admin  (192.168.56.10)
- web    (192.168.56.20) ← Nginx dans Docker, sert l'application
- infra  (192.168.56.30) ← Bind9 (DNS) + entrées hosts de commodité

Redirections de ports sur l’hôte :
- HTTP  : http://localhost:8081
- HTTPS : https://localhost:8444 (auto-signé)

## Prérequis
- Windows 10/11
- PowerShell 5.1+
- VirtualBox (6.x/7.x)
- Vagrant (2.3+)

> Remarque : Des playbooks Ansible sont fournis pour référence et usage futur, mais le script PowerShell fourni déploie sans nécessiter Ansible sous Windows.

## Déploiement en un clic (Windows)

À exécuter depuis la racine du dépôt :

```powershell
# PowerShell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
./scripts/deploy.ps1
```

Ce que fait le script :
- Lance `vagrant up` sur toutes les VM
- Infra : installe et configure Bind9 avec une zone locale `testdnsfilrouge.local` (enregistrements admin/web/infra)
- Web : installe Docker + docker-compose, arrête nginx hôte, charge `app/`, génère un certificat auto-signé, écrit `default.conf`, lance `docker-( )compose up -d`
- Admin/Web : pointe le résolveur DNS vers Infra (systemd-resolved) pour résoudre `*.testdnsfilrouge.local`

Après succès, ouvrez :
- HTTP  → http://localhost:8081
- HTTPS → https://localhost:8444 (acceptez l’avertissement du certificat)

## Structure du projet
- `Vagrantfile` — 3 VM (admin, web, infra)
- `app/` — docker-compose et site statique (monté dans le conteneur Nginx)
- `*.yml` — Playbooks Ansible (optionnels, non requis par le déploiement PowerShell)
- `scripts/deploy.ps1` — déploiement Windows en un clic

## 🌐 Mise en place du DNS Interne

- Configuration du Domaine : création du domaine local `testdnsfilrouge.local` sur la VM `infra` (Bind9). Vous pouvez vous appuyer sur le playbook `dns_configuration.yml` si vous souhaitez l’automatiser.
- Résolution de Problème : sur la VM `admin`, forcer le résolveur à pointer vers la VM `infra` (`192.168.56.30`).
	- Méthode rapide (temporaire, peut être écrasée par systemd-resolved) :
		```powershell
		vagrant ssh admin -c "sudo bash -lc 'grep -q "nameserver 192.168.56.30" /etc/resolv.conf || echo nameserver 192.168.56.30 | sudo tee -a /etc/resolv.conf'"
		```
	- Méthode persistante (Ubuntu 22.04, systemd-resolved) :
		```powershell
		vagrant ssh admin -c "sudo mkdir -p /etc/systemd/resolved.conf.d; echo -e '[Resolve]\nDNS=192.168.56.30\nDomains=testdnsfilrouge.local' | sudo tee /etc/systemd/resolved.conf.d/filrouge.conf; sudo systemctl restart systemd-resolved"
		```
- Résultat : valider la résolution avec `dig` et `curl`.
	```powershell
	# Interroger le serveur DNS infra directement
	vagrant ssh admin -c "dig @192.168.56.30 testdnsfilrouge.local +noall +answer"
	vagrant ssh admin -c "dig @192.168.56.30 web.testdnsfilrouge.local A +short"

	# Tester un accès HTTP(S) basique
	vagrant ssh admin -c "curl -I http://web || curl -I http://192.168.56.20"
	vagrant ssh admin -c "curl -I -k https://web || curl -I -k https://192.168.56.20:443"
	```

## Dépannage
- Si `vagrant up` échoue, essayez `vagrant destroy -f; vagrant up` pour réinitialiser le labo.
- Docker peut nécessiter une reconnexion pour que l’utilisateur `vagrant` prenne en compte le groupe `docker` ; le script lance Docker de manière non interactive, donc cela devrait fonctionner malgré tout.
- Si les ports 8081/8444 sont occupés, modifiez-les dans `Vagrantfile`, puis exécutez `vagrant reload --provision` puis `./scripts/deploy.ps1`.
- Un simple `vagrant up` (sans `scripts/deploy.ps1`) ne configure pas automatiquement le DNS. Utilisez le script pour Bind9 + configuration des résolveurs.

## Sauvegarde et restauration (snapshots)

Pour figer l’état des VM et revenir en arrière rapidement, utilisez les snapshots Vagrant (supportés par VirtualBox) :

### Créer un snapshot (par machine)

```powershell
# Depuis la racine du dépôt
vagrant snapshot save admin baseline
vagrant snapshot save web baseline
vagrant snapshot save infra baseline
```

### Restaurer un snapshot

```powershell
vagrant snapshot restore admin baseline
vagrant snapshot restore web baseline
vagrant snapshot restore infra baseline
```

### Lister / supprimer des snapshots

```powershell
# Lister
vagrant snapshot list web

# Supprimer
vagrant snapshot delete web baseline
```

Conseils :
- Donnez des noms explicites (ex. `baseline`, `avant_tests`, `après_dns`).
- Les snapshots consomment de l’espace disque ; nettoyez ceux qui ne sont plus utiles.
- Après une restauration, si des services ne redémarrent pas, essayez `vagrant reload --provision` pour reprovisionner.

### Nommage basé sur la date (recommandé)

Pour des checkpoints ordonnés, utilisez un horodatage dans le nom :

```powershell
$ts = Get-Date -Format 'yyyyMMdd-HHmm'
vagrant snapshot save web "snap-$ts"
```

### Script d’assistance

Un script est fourni pour automatiser les snapshots avec un nom daté par défaut : `scripts/snapshot.ps1`.

Exemples :

```powershell
# Sauvegarder (toutes les machines) avec nom daté : snap-YYYYMMDD-HHMMSS
./scripts/snapshot.ps1 -Action save

# Lister
./scripts/snapshot.ps1 -Action list

# Restaurer
./scripts/snapshot.ps1 -Action restore -Name snap-20251217-103000

# Supprimer sans confirmation
./scripts/snapshot.ps1 -Action delete -Name snap-20251217-103000 -Yes
```

## Prochaines étapes (optionnel)
- Câbler Ansible pour s’exécuter depuis la VM `admin` comme contrôleur (ajouter inventaire et distribution de clés).
- Ajouter des GitHub Actions pour linter Ansible/YAML et valider le fichier Compose.
- Paramétrer les réglages communs via un fichier `.env`.
