#!/bin/bash
set -e

systemctl disable --now firewalld 2>/dev/null || true
setenforce 0 2>/dev/null || true
sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config 2>/dev/null || true

curl -sfL https://get.k3s.io | sh -s - \
  --write-kubeconfig-mode 644 \
  --node-ip 192.168.56.110 \
  --tls-san 192.168.56.110

ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl

until kubectl get nodes &>/dev/null; do
  echo "Waiting for K3s API..."
  sleep 5
done

kubectl wait --for=condition=Ready nodes --all --timeout=180s

echo "Deploying apps..."
kubectl apply -f /vagrant/confs/app1.yaml
kubectl apply -f /vagrant/confs/app2.yaml
kubectl apply -f /vagrant/confs/app3.yaml
kubectl apply -f /vagrant/confs/ingress.yaml

echo "All apps deployed."
kubectl get all
kubectl get ingress