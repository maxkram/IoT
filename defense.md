# Inception-of-Things — Defense Preparation

## Concepts (be ready to explain simply)

### K3s
Lightweight Kubernetes by Rancher. Single binary. Server = control plane (API, etcd, scheduler, controller-manager). Agent = worker (kubelet, kube-proxy, containerd).

### Vagrant
Manages VMs via Vagrantfile. Uses providers (VirtualBox here). `vagrant up`, `vagrant ssh`, `vagrant halt`. Shared folder `/vagrant` = project dir on host.

### K3d
Runs K3s nodes inside Docker containers. Faster than Vagrant for local dev. `k3d cluster create <name>`. Auto-configures kubeconfig.

### Argo CD
GitOps tool. Watches a Git repo, applies manifests to cluster automatically. Declarative continuous delivery. Web UI for sync status.

---

## Part 1

### Verification commands
```
vagrant up
vagrant ssh mkramerS
ifconfig eth1            # expect 192.168.56.110
hostname                 # expect mkramerS
sudo kubectl get nodes -o wide   # expect 2 Ready nodes
```

### Questions to prepare
- **How does the worker join?** Server writes `/var/lib/rancher/k3s/server/node-token`. Shared to worker via /vagrant. Worker runs K3s install with `K3S_URL` + `K3S_TOKEN`.
- **Why private network?** Allows stable IPs between VMs and host. NAT alone doesn't give host access.
- **Why CentOS?** Checklist requires latest stable CentOS. Used `eurolinux-vagrant/centos-stream-9`.
- **K3s vs full K8s?** K3s is K8s minus legacy/cloud provider bloat. Single binary, same APIs.

---

## Part 2

### Verification commands
```
vagrant up
vagrant ssh mkramerS
sudo kubectl get nodes -o wide
sudo kubectl get all
sudo kubectl get ingress
curl -H "Host: app1.com" http://192.168.56.110   # expect APP 1
curl -H "Host: app2.com" http://192.168.56.110   # expect APP 2
curl http://192.168.56.110                        # expect APP 3 (default)
```

### Questions to prepare
- **How does routing work?** K3s ships with Traefik Ingress controller. Ingress resource defines host-based rules.
- **Why 3 replicas on app2?** Spec requires it. `replicas: 3` in Deployment.
- **Show the Ingress:** `kubectl get ingress` and `kubectl describe ingress apps-ingress`.

---

## Part 3

### Verification commands
```
bash scripts/install.sh      # once per VM
bash scripts/deploy.sh
kubectl get ns               # expect argocd, dev
kubectl get pods -n argocd
kubectl get pods -n dev      # expect wil-playground pod
# Login Argo CD: https://localhost:8443, user=admin, password from secret
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
curl http://localhost:8888   # expect {"message":"v1"}
```

### Version change test
1. In GitHub config repo, edit `dev/deployment.yaml`: `v1` → `v2`
2. Commit + push
3. Argo CD auto-syncs (or click Sync in UI)
4. `curl http://localhost:8888` should return `{"message":"v2"}`

### Questions to prepare
- **K3s vs K3d?** K3s = real cluster on VMs. K3d = K3s inside Docker. K3d is local-only, simpler.
- **Namespace vs Pod?** Namespace = cluster-level logical grouping (isolation, quotas). Pod = smallest deployable unit running containers.
- **Why GitOps?** Git is source of truth. Argo CD detects drift and reconciles.
- **Argo CD auth?** Initial admin password in Secret `argocd-initial-admin-secret`.

---

## Bonus (if asked)
- GitLab via Helm in `gitlab` namespace
- Argo CD reconfigured to watch local GitLab instead of GitHub
- Same v1→v2 flow works

---

## Risks / things to test

- CentOS Stream 9 box download may be slow. Pre-download with `vagrant box add eurolinux-vagrant/centos-stream-9`.
- K3s on CentOS may need SELinux disabled or permissive. Add `setenforce 0` in bootstrap if needed.
- Traefik v2 uses `networking.k8s.io/v1` — older `extensions/v1beta1` will fail.
- Vagrant port 80 on host may conflict with existing services. Change if needed.
- For p3, Docker must be running. Add user to docker group, then `newgrp docker`.
