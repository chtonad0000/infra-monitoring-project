# infra-monitoring-project

## Запуск

```bash
git clone -b feature/monitoring https://github.com/chtonad0000/infra-monitoring-project.git
cd infra-monitoring-project
chmod +x check_api.sh analyze_logs.sh
docker-compose up -d
docker-compose ps
curl http://localhost:80
```

Ответ: `Monitoring Service Active`.

Остановка:

```bash
docker-compose down
```

## Скрипты

`check_api.sh <URL>`: код возврата `0` при HTTP 200, `1` при ошибке.

```bash
./check_api.sh https://httpbin.org/status/200
echo $?
./check_api.sh not-a-url
echo $?
```

`analyze_logs.sh [файл]`: без аргумента создаёт `access.log` на 360 строк, если его нет.

```bash
./analyze_logs.sh
./analyze_logs.sh /path/to/access.log
```

## SSH/SCP

`deploy@example.com` — пользователь и адрес сервера. На сервере нужен Docker Compose.

Создание ключа и копирование публичной части. Для ключа задайте парольную фразу.

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_infra
ssh-copy-id -i ~/.ssh/id_ed25519_infra.pub deploy@example.com
```

При первом подключении проверьте отпечаток ключа сервера.

Архив и передача из каталога проекта:

```bash
tar -czf ../infra-monitoring-project.tar.gz \
    README.md .gitignore .github check_api.sh analyze_logs.sh docker-compose.yml nginx
scp -i ~/.ssh/id_ed25519_infra ../infra-monitoring-project.tar.gz deploy@example.com:/tmp/
```

Запуск на сервере:

```bash
ssh -i ~/.ssh/id_ed25519_infra deploy@example.com <<'EOF'
set -e
mkdir -p ~/infra-monitoring-project
tar -xzf /tmp/infra-monitoring-project.tar.gz -C ~/infra-monitoring-project
cd ~/infra-monitoring-project
docker-compose up -d
curl http://localhost:80
EOF
```
