#!/bin/bash

# Admin 노드에서 SSH 키가 없으면 생성
if [ ! -f /home/vagrant/.ssh/id_rsa ]; then
    echo "Generating SSH key for vagrant user..."
    sudo -u vagrant ssh-keygen -t rsa -N "" -f /home/vagrant/.ssh/id_rsa
fi

# known_hosts에 다른 서버 IP 추가 (처음 접속 시 질문 건너뛰기 위함)
echo "Adding Web and Infra IPs to known_hosts..."
ssh-keyscan 192.168.56.20 >> /home/vagrant/.ssh/known_hosts
ssh-keyscan 192.168.56.30 >> /home/vagrant/.ssh/known_hosts
chown vagrant:vagrant /home/vagrant/.ssh/known_hosts