# cannonball

`cannonball` это внутренняя система рассылок. Через неё можно отправлять сообщения в личку, в каналы и вести историю отправок. У приложения есть пользовательский и административный контур: пользователь работает с рассылками, администратор настраивает интеграции, доступ и параметры платформы.

Сейчас из коробки работают `Mattermost`, `n8n`, `Keycloak` и почтовое восстановление доступа. Под `Slack` и `Rocket.Chat` архитектура уже подготовлена, но сами драйверы пока не реализованы.

## Что умеет

- отправка рассылок по пользователям, группам и каналам
- история отправок
- локальные пользователи и роли
- локальный вход и SSO через Keycloak
- восстановление пароля по почте
- запуск через Docker, Helm и как Linux-бинарь

## Быстрый запуск через Docker

Если нужен самый простой старт:

```bash
cp .env.example .env
docker compose up --build
```

После запуска приложение будет доступно на `http://localhost:8080`.

Что важно:

- база хранится в persistent volume
- по умолчанию используется `SQLite`
- для первого входа нужно задать `APP_PASSWORD` или `APP_PASSWORD_HASH` в `.env`

Если хочется поставить всё одной командой на Linux и сразу поднять Docker-стек, теперь есть отдельный install-скрипт:

```bash
./scripts/install-docker.sh
```

Скрипт:

- создаёт `.env`, если его ещё нет
- генерирует пароль администратора, если он не задан
- поднимает приложение через Docker Compose
- делает bind mount для базы на Linux-каталог
- печатает URL, логин и пароль первого администратора

Если запуск идёт не из репозитория, а прямо через `curl`, можно использовать тот же скрипт из raw URL. Для этого нужен raw URL самого скрипта и URL архива репозитория:

```bash
curl -fsSL https://raw.githubusercontent.com/papasahti/cannonball/main/scripts/install-docker.sh | bash
```

Этой команды достаточно. Скрипт сам:

- скачает текущую `main` ветку из GitHub
- положит проект в `/opt/cannonball-docker`
- создаст `.env`
- сгенерирует пароль администратора
- поднимет приложение через `docker compose`
- сохранит базу в `/var/lib/cannonball`

Если нужно, можно переопределить ветку или репозиторий:

```bash
curl -fsSL https://raw.githubusercontent.com/papasahti/cannonball/main/scripts/install-docker.sh | \
  CANNONBALL_REPO_REF=main \
  bash
```

Что можно переопределить:

- `CANNONBALL_PORT`
- `CANNONBALL_APP_PASSWORD`
- `CANNONBALL_INSTALL_DIR`
- `CANNONBALL_DATA_DIR`
- `CANNONBALL_PUBLIC_URL`
- `CANNONBALL_REPO_URL`
- `CANNONBALL_REPO_REF`
- `CANNONBALL_REPO_ARCHIVE_URL`

## Установка на Linux

Если Docker не нужен и приложение хочется поставить как обычный сервис:

```bash
./scripts/build-linux-release.sh
tar -xzf build/linux-release/cannonball-linux-x64.tar.gz
cd build/linux-release/cannonball-linux-x64
sudo ./install.sh
```

После установки:

- бинарь будет лежать в `/opt/cannonball/bin/cannonball`
- конфиг в `/etc/cannonball/cannonball.env`
- база в `/var/lib/cannonball/cannonball.db`
- сервис запускается через `systemd`

Проверка:

```bash
systemctl status cannonball
curl http://127.0.0.1:8080/health
```

## Запуск через Helm

Chart лежит в `helm/cannonball`.

Минимальный пример:

```bash
helm upgrade --install cannonball ./helm/cannonball \
  --set image.repository=registry.example.com/team/cannonball \
  --set image.tag=latest \
  --set env.APP_PASSWORD='change-me' \
  --set env.APP_BASE_URL='https://cannonball.example.com'
```

Для текущего chart важно помнить:

- по умолчанию используется `SQLite`
- база хранится в PVC
- `replicaCount=1`
- стратегия обновления `Recreate`

Это нормальный режим для одного инстанса приложения. Если дальше понадобится горизонтальное масштабирование, следующим шагом уже стоит подключать внешний storage provider, например PostgreSQL.

## Интеграции

### Mattermost

Основная интеграция на сегодня. Используется как каталог пользователей и как прямой канал доставки.

Нужно заполнить:

- `MATTERMOST_BASE_URL`
- `MATTERMOST_TOKEN`
- `MATTERMOST_TEAM_ID` или `MATTERMOST_TEAM_NAME`

### n8n

Нужен, если хочется вынести маршрутизацию и автоматизацию во внешний workflow-контур.

Нужно заполнить:

- `N8N_BASE_URL`
- `N8N_WEBHOOK_URL`
- `N8N_API_KEY`
- `N8N_WEBHOOK_SECRET`
- `N8N_INBOUND_SECRET`

Если хочется, чтобы `n8n` не только принимал события из `cannonball`, но и сам запускал рассылки в продукте, можно использовать входящий endpoint:

```text
POST /api/incoming/n8n
Authorization: Bearer <N8N_INBOUND_SECRET>
Content-Type: application/json
```

Самый простой payload выглядит так:

```json
{
  "rule_key": "incident-critical",
  "message": "Падает billing",
  "request_id": "evt-001"
}
```

Как это работает:

- `rule_key` выбирает правило в админке
- `message` становится текстом рассылки
- `request_id` нужен для дедупликации, чтобы одно и то же событие не ушло дважды

Если правило не нужно, можно передать адресатов прямо в payload:

```json
{
  "message": "Сервис будет недоступен с 22:00 до 22:15",
  "users": ["ivanov", "petrov"],
  "groups": ["oncall"],
  "channels": ["alerts"],
  "request_id": "evt-002"
}
```

Для быстрой ручной проверки есть готовый smoke-скрипт:

```bash
INBOUND_SECRET=change-me ./scripts/smoke-inbound-n8n.sh
```

### Keycloak

Используется для SSO.

Нужно заполнить:

- `AUTH_MODE`
- `KEYCLOAK_ISSUER_URL`
- `KEYCLOAK_CLIENT_ID`
- `KEYCLOAK_CLIENT_SECRET`

### Почта

Нужна для восстановления пароля.

Нужно заполнить:

- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_USERNAME`
- `SMTP_PASSWORD`
- `SMTP_FROM_EMAIL`

### Slack и Rocket.Chat

Пока не подключены. Но приложение уже разложено так, чтобы эти интеграции можно было добавить отдельными модулями, без переписывания всего сервера.

## Где искать подробности

Подробная техническая документация, заметки по эксплуатации и внутренние архитектурные комментарии вынесены в `.ai/`. Этот каталог не коммитится в git.
