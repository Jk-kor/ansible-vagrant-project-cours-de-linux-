#!/bin/bash

# Sur le nœud Admin, générer une clé SSH si absente
if [ ! -f /home/vagrant/.ssh/id_rsa ]; then
    echo "Generating SSH key for vagrant user..."
    sudo -u vagrant ssh-keygen -t rsa -N "" -f /home/vagrant/.ssh/id_rsa
fi

# Ajouter les IP des autres serveurs à known_hosts (éviter l'invite lors de la première connexion)
echo "Adding Web and Infra IPs to known_hosts..."
ssh-keyscan 192.168.56.20 >> /home/vagrant/.ssh/known_hosts
ssh-keyscan 192.168.56.30 >> /home/vagrant/.ssh/known_hosts
chown vagrant:vagrant /home/vagrant/.ssh/known_hosts