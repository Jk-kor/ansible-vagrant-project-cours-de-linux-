#!/bin/bash

echo "Starting /etc/hosts fix on Web server..."

# Admin, Web, Infra 노드 정보를 /etc/hosts 파일에 추가하는 명령어
HOSTS_ENTRY="192.168.56.10 admin\n192.168.56.20 web\n192.168.56.30 infra"

# SSH를 통해 Web 서버에 접속하여 hosts 파일 수정 실행
ssh web "sudo sed -i '/192.168.56.10/d; /192.168.56.20/d; /192.168.56.30/d' /etc/hosts"
ssh web "echo -e '${HOSTS_ENTRY}' | sudo tee -a /etc/hosts"

echo "Web server /etc/hosts fix complete."
