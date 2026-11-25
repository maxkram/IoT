# Inception-of-Things - подготовка к защите

## Окружение (важно, это первое, о чем спросят логи установки)

- Дистрибутив везде Ubuntu 24.04, бокс bento/ubuntu-24.04. Изначально был CentOS Stream 9, но на AlmaLinux/CentOS worker не мог подключиться к серверу (6443 недоступен, симптом: висит Starting k3s-agent), плюс 512 МБ убивали установку SELinux-политики. Переезд на Ubuntu решил оба.
- Зеркало боксов: Vagrant Cloud заблокирован из РФ, поэтому в Vagrantfile первая строка `ENV['VAGRANT_SERVER_URL'] = 'https://vagrant.elab.pro'`.
- Порядок частей: p1 и p2 имеют одинаковое имя ВМ mkramerS, вместе не живут. Перед p2 делай `vagrant destroy -f` в p1. Перед p3 делай `vagrant destroy -f` в p2 (p3 работает без Vagrant, на хосте).
- Если traefik не отвечает на 80 порту сразу, это нормально: он поднимается 4-5 минут после vagrant up. Проверяй `kubectl get all -A`.

## Концепции (объяснять простыми словами)

### K3s
Легковесный Kubernetes от Rancher, один бинарник. Server это control plane (API, etcd, scheduler, controller-manager). Agent это worker (kubelet, kube-proxy, containerd).

### Vagrant
Управляет ВМ через Vagrantfile, provider VirtualBox. Команды: vagrant up, vagrant ssh, vagrant halt, vagrant destroy. Общая папка /vagrant внутри ВМ это каталог проекта на хосте.

### K3d
Запускает узлы K3s внутри Docker-контейнеров. Быстрее Vagrant для локальной разработки. `k3d cluster create iot`. Сам настраивает kubeconfig.

### Argo CD
GitOps-инструмент. Следит за git-репозиторием и применяет манифесты в кластер автоматически. Декларативный continuous delivery. Веб-UI показывает статус синхронизации.

## Part 1

### Команды проверки
```bash
cd p1
vagrant destroy -f
vagrant up
vagrant ssh mkramerS
hostname # ожидается mkramerS
ip a show eth1 | grep inet # ожидается 192.168.56.110
sudo kubectl get nodes -o wide # 2 ноды Ready
```

### Ответы на вопросы
- Как worker вступает в кластер? Сервер пишет токен в /var/lib/rancher/k3s/server/node-token, bootstrap копирует его в /vagrant, worker читает оттуда и ставит k3s с K3S_URL (https://192.168.56.110:6443) и K3S_TOKEN.
- Зачем private network? NAT не дает стабильных IP и доступа хоста к ВМ. Host-only сеть 192.168.56.0/24 дает фиксированные адреса .110 и .111.
- Почему SSH без пароля? Vagrant генерирует ключевую пару при первом up и подкладывает публичный ключ в ВМ.
- Где kubectl? Это симлинк на бинарь k3s, k3s умеет работать как kubectl. Официально поддерживаемый способ.
- K3s против полного K8s? Те же API, но один бинарь без устаревших и облачных компонентов.

## Part 2

### Команды проверки

```bash
cd p2
vagrant up
vagrant ssh mkramerS -c "sudo kubectl get all"
vagrant ssh mkramerS -c "sudo kubectl get ingress"
curl -H "Host: app1.com" http://192.168.56.110 # APP 1
curl -H "Host: app2.com" http://192.168.56.110 # APP 2
curl http://192.168.56.110 # APP 3 (default)
```

### Ответы на вопросы
- Как работает маршрутизация? В K3s встроен Traefik как Ingress controller. Ресурс Ingress задает правила по Host-заголовку. Правило без host ловит все остальное, это app3.
- Почему у app2 три реплики? Требование предметника, replicas: 3 в Deployment.
- Показать Ingress: `sudo kubectl get ingress` и `sudo kubectl describe ingress apps-ingress`.
- Внимание на тайминг: traefik поднимается до 5 минут. Если curl падает с connection refused, смотри `kubectl get all -A`, жди READY у svclb-traefik.

## Part 3

### Команды проверки
```bash
cd p3
bash scripts/install.sh # один раз на машине: docker, k3d, kubectl
newgrp docker # или перелогин
bash scripts/deploy.sh
kubectl get ns # ожидаются argocd, dev
kubectl get pods -n dev # под wil-playground
curl http://localhost:8888 # {"status":"ok", "message": "v1"}
```
UI Argo CD:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
kubectl port-forward svc/argocd-server -n argocd 8443:443

```
Открыть https://localhost:8443, пользователь admin, пароль из первой команды.

### Демонстрация v1 -> v2
1. В GitHub-репо правим dev/deployment.yaml: v1 на v2, commit, push.
2. Argo CD синкает автоматически раз в 3 минуты. Не ждем: в UI кнопка Refresh на приложении.
3. curl http://localhost:8888 должен вернуть v2.
4. После демо вернуть v1, commit, push.

### Ответы на вопросы
- K3s против K3d? K3s это кластер на настоящих ВМ или железе. K3d это тот же k3s, но узлы в Docker-контейнерах, только для локальной разработки.
- Namespace против Pod? Namespace это логическая изоляция ресурсов кластера. Pod это минимальная единица деплоя, один или несколько контейнеров.
- Зачем GitOps? Git единственный источник правды, Argo CD сам находит расхождения и приводит кластер к состоянию из git (selfHeal).
- Почему в деплое --server-side? Свежий Argo CD содержит CRD applicationsets с аннотацией больше лимита 262144 байт, обычный kubectl apply падает. Server-side apply обходит это.
- Откуда пароль админа? Из Secret argocd-initial-admin-secret в namespace argocd.

## Бонус (если спросят)
- GitLab через Helm в namespace gitlab.
- Argo CD перенастроить на локальный GitLab вместо GitHub.
- Тот же цикл v1 -> v2 должен работать.
- Это не сделано, только план.

## Заметки и риски
- В public-репо только конфиги. Никаких kubeconfig и node-token, они в .gitignore.
- Требование предметника: логин члена команды в имени GitHub-репо (mkramer-iot). Временное имя IoT переименовать перед защитой и поправить repoURL в p3/confs/application.yaml.
- Скрипт install.sh рассчитан на Ubuntu защитной VM кампуса, скачивание из интернета обязательно.
- install.sh на машине кампуса: репозиторий Docker может не знать новый коднейм Ubuntu, тогда подставить noble в строку репо по образцу обхода с HashiCorp.
---

### Проверка
```bash
VBoxManage list runningvms
k3d cluster list
```
### Остановить кластер
```bash
k3d cluster stop iot
```
### Запустить кластер
```bash
k3d cluster start iot
```
### Полное удаление
```bash
k3d cluster delete iot
```