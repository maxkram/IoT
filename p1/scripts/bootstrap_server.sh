#!/bin/bash
set -e

# CentOS Stream 9: firewalld блокирует порты K3s (6443, flannel 8472/udp)
systemctl disable --now firewalld 2>/dev/null || true
setenforce 0 2>/dev/null || true
sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config 2>/dev/null || true

# K3s в режиме сервера (controller)
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_SKIP_SELINUX_RPM=true \
  sh -s - \
  --write-kubeconfig-mode 644 \
  --node-ip 192.168.56.110 \
  --tls-san 192.168.56.110 \
  --bind-address 0.0.0.0

ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl

until [ -f /var/lib/rancher/k3s/server/node-token ]; do
  echo "Waiting for node-token..."
  sleep 2
done

cp /var/lib/rancher/k3s/server/node-token /vagrant/node-token
cp /etc/rancher/k3s/k3s.yaml /vagrant/kubeconfig
sed -i 's/127.0.0.1/192.168.56.110/g' /vagrant/kubeconfig

echo "K3s server ready."