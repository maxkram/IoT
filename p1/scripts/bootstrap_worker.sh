#!/bin/bash
set -e

systemctl disable --now firewalld 2>/dev/null || true
setenforce 0 2>/dev/null || true
sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config 2>/dev/null || true

until [ -f /vagrant/node-token ]; do
  echo "Waiting for node-token from server..."
  sleep 2
done

TOKEN=$(cat /vagrant/node-token)

curl -sfL https://get.k3s.io | \
  K3S_URL=https://192.168.56.110:6443 \
  K3S_TOKEN=$TOKEN \
  sh -s - \
  --node-ip 192.168.56.111

ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl

echo "K3s agent joined cluster."