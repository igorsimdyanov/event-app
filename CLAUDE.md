# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## О репозитории

Workshop по событийной архитектуре: восемь Rails-приложений (Ruby 4.0.5, Rails 8.1) обмениваются
сообщениями через RabbitMQ. Конвейер обрабатывает товарные чеки: письмо с вложением → распознавание →
извлечение суммы → автоматическая регистрация (≤ 200 ₽) либо ручное одобрение держателем бюджета →
регистрация стоимости.

Каждый микросервис — самостоятельное Rails-приложение со своей БД, `Gemfile` и `docker-compose.yaml`.
Общего кода между ними нет: единообразие достигается генерацией из `microservice-template`, поэтому
правку общего каркаса (воркер, подключение к RabbitMQ, локали) нужно вносить в каждый сервис отдельно
и в шаблон.

## Команды

Все команды выполняются **из корня репозитория**. Внутри каждого микросервиса лежит собственный
`docker-compose.yaml` — запуск `docker compose` из каталога сервиса поднимает отдельный compose-проект
и не видит контейнеров, запущенных из корня (типичный источник «service is not running»).

```bash
docker compose up -d                      # поднять всю систему
docker compose build event-logger         # пересобрать образ сервиса
docker compose logs --tail 50 event-logger-sneakers
```

БД разворачивается отдельно для каждого сервиса, использующего Postgres
(inbox, check-manager, check-ruler, check-register, budget-control, event-logger):

```bash
docker compose run --rm event-logger bundle exec rake db:create db:migrate
```

Тесты (RSpec + FactoryBot + SimpleCov):

```bash
docker compose exec -e RAILS_ENV=test event-logger bundle exec rake db:test:prepare
docker compose exec -e RAILS_ENV=test event-logger bundle exec rspec
docker compose exec -e RAILS_ENV=test event-logger bundle exec rspec spec/models/check_spec.rb:42
```

Отладка и вспомогательное:

```bash
docker compose exec event-logger bundle exec rails runner 'puts Check.count'
docker compose exec event-logger bundle exec rake fake_message:start   # тестовое сообщение в очередь сервиса
npx -y @asyncapi/cli validate docs/asyncapi.yaml
```

**RuboCop не запускается**: установленная версия не знает Ruby 4.0 (`unknown Ruby version 4.0
in .ruby-version`). Конфиг `.rubocop.yml` есть, но проверить стиль автоматически нельзя — ориентируйся
на код рядом.

## Обмен сообщениями

Один durable topic-обменник `services`. **AMQP routing key совпадает с полем `action`** сообщения
(исключение — ответ `recognized_result`, который отправляется по ключу из `reply_to` запроса).

Формат конверта (ADR-0005): мета-поля на верхнем уровне, полезная нагрузка в `payload`:

```json
{ "action": "pay_analyse", "payload": { "attachment_id": "…", "…": "…" },
  "created_at": 1761736906, "routing_key": "pay_analyse", "reply_to": "recognized_result" }
```

`payload.attachment_id` — сквозной correlation-id всей бизнес-транзакции (ADR-0004), создаётся один раз
в inbox и передаётся неизменным по всей цепочке. `created_at` — Unix timestamp момента создания
сообщения в сервисе-источнике; именно он, а не время записи в БД, задаёт хронологию.

| action | очередь | потребитель | обработчик |
|---|---|---|---|
| `attachment_registered` | `inbox.out` | check-manager (`InboxListener`) | `Checks::RecognizeService` |
| `recognize` | `tesseract.in`, `yandex_vision.in` | tesseract, yandex-vision | `Checks::RecognizeService` |
| `recognized_result` | `recognizer.out` | check-manager (`RecognizerListener`) | `Pays::AnalyseService` |
| `pay_analyse` | `check_manager.out` | check-ruler | `Price::PayAnalyseService` |
| `budget_check` | `budget_control.in` | budget-control | `Checks::RegisterService` |
| `pay_register` | `register.in` | check-register | `Checks::RegisterService` |
| любой | `event_logger.in` | event-logger | `Events::RegisterService` |

Очереди объявляет и привязывает сам потребитель — через `RabbitBindQueues.create_for(Worker)`, который
вызывается в конце файла воркера (ADR-0003). Ключи привязки берутся из `ACTION_HANDLERS.keys`, а в
event-logger — из `BINDING_KEYS` (маска `#`, копия всего трафика обменника).

У каждой очереди есть парная очередь ошибок `<очередь>.error` (ADR-0009): константы `QUEUE_DEAD_LETTER`,
`DEAD_LETTER_ARGUMENTS` и `ARGUMENTS` в воркере, объявление — в `RabbitBindQueues`. Отклонённое
(`reject!`) сообщение уходит туда через обменник `services` и ждёт ручного возврата из консоли
(рецепты — в ADR-0009). Исключение — `event_logger.in`: её dead-letter идёт через обменник по
умолчанию, иначе сообщение вернулось бы в неё же по маске `#` и зациклилось.

**Аргументы существующей очереди изменить нельзя**: повторное объявление с другими параметрами даёт
`PRECONDITION_FAILED`, и воркер не стартует. Меняя `ARGUMENTS`, нужно удалить очередь в брокере
(предварительно сохранив сообщения) и дать сервису создать её заново.

Данные брокера лежат на томе `rabbitmq-data`, поэтому очереди, привязки и накопленные сообщения
переживают пересоздание контейнера. Работает это только в паре с `hostname: rabbitmq` в
docker-compose: каталог данных называется по имени узла (`rabbit@<hostname>`), и без фиксированного
имени пересозданный контейнер завёл бы пустой узел рядом со старым. Очередь `yandex_vision.in`
существует только благодаря тому: её объявляет незапущенный сервис, и после очистки тома её
придётся создавать руками.

Спецификация обмена — `docs/asyncapi.yaml`. **При изменении набора сообщений, каналов или очередей
её нужно обновлять**; она валидируется CLI (см. команды выше).

## Каркас микросервиса

Сервисы (кроме inbox) сгенерированы из `microservice-template` — `template.rb` копирует файлы из
`microservice-template/templates`. Правя общий каркас, обновляй и шаблон, иначе следующий
сгенерированный сервис получит старое поведение.

- `app/workers/*_listener.rb` — потребитель Sneakers (гем `kicks`). Константы `ACTION_HANDLERS`
  (action → сервис-объект) и `QUEUE_NAME`; метод `work` парсит JSON, вызывает обработчик и делает
  `ack!`, при ошибке — `reject!`. В сервисах с БД воркер дополнительно пишет входящее `RabbitMessage`
  и помечает его неуспешным при исключении, а ошибки Postgres из `PG_EXCEPTION` обрабатывает отдельно:
  переподключение и `requeue!`. У tesseract и yandex-vision БД нет, поэтому воркер короче.
- `lib/rabbit_messages/` — набор файлов зависит от роли сервиса: `Send` + `BaseAmqp` (публикация,
  заглушка обменника при `SNEAKERS_AMQP_STUB`) есть только у тех, кто отправляет сообщения,
  `Logging` (журнал в таблицу `rabbit_messages`) — у тех, у кого есть БД. У check-register только
  `Logging` (конечная точка конвейера), у tesseract и yandex-vision нет `Logging` (нет БД),
  у event-logger нет ничего из этого.
- `config/initializers/rabbitmq.rb` — `RabbitConnectionManager` с thread-local соединением Bunny.
- `app/contexts/<домен>/*_service.rb` — бизнес-логика (ADR-0008): «кричащие» имена папок по доменам,
  единственная публичная точка входа `call`, модуль `Callable` (`Service.call(args)` → `new(args).call`),
  аргументы через `dry-initializer`. В моделях и контроллерах бизнес-логики нет.
- `config/settings.yml` + гем `config` → `Settings.*`; значения приходят из ENV, файл `.env` не в git
  (копируется из `sample.env`, в docker-compose ключевые переменные продублированы в `environment`).
- ActiveAdmin **без авторизации** (`authentication_method` отключён), панель на `/admin`.
- Модель `RabbitMessage` — журнал входящих и исходящих сообщений сервиса. В event-logger её нет:
  там журналом служат сами `events`.
- `lib/metrics/` — экспортер метрик Prometheus (ADR-0010): собственный TCP-сокет в фоновом потоке
  на порту 9394, поднимается из `config/initializers/metrics.rb`. Каталог исключён из автозагрузки
  (`config.autoload_lib(ignore: %w[assets tasks metrics])`) и подключается через `require`: поток
  переживает перезагрузку кода. `Metrics::ProcessInfo.kind` возвращает `nil` для консоли, rake-задач
  и спеков — там экспортер не стартует и порт не занимает.
- Две точки входа: `rails s` (панель) и `rails sneakers:run` (потребитель). В compose это два
  контейнера на одном образе: `<сервис>` и `<сервис>-sneakers`.

## Особенности отдельных сервисов

- **inbox** — единственный не из шаблона: читает IMAP, кладёт вложения в S3 (carrierwave), публикует
  `attachment_registered`. Работает не через Sneakers, а через SolidQueue: `bin/jobs` + расписание в
  `config/recurring.yml` (`ExtractEmailJob`, `SentAttachmentJob`). ActiveAdmin нет, api-only.
- **check-manager** — оркестратор с двумя потребителями (`InboxListener`, `RecognizerListener`) и,
  соответственно, двумя очередями из `Settings.sneakers`.
- **tesseract / yandex-vision** — api-only распознаватели, отвечают по ключу из `reply_to`.
  yandex-vision в корневом docker-compose не запущен: очередь `yandex_vision.in` существует без
  потребителей.
- **check-ruler** — точка ветвления: сумма ≤ 200 ₽ → `pay_register`, иначе (или если сумма не
  распознана) → `budget_check`.
- **budget-control** — ручное одобрение в админке (`member_action :approve`), после чего публикует
  сокращённый `pay_register` (без `file`, `created_at`, `message`).
- **event-logger** — журнал всех событий, стоит в стороне от конвейера. Использует
  `work_with_params`, чтобы получить фактический routing key доставки; группирует события в `checks`
  по `attachment_id`; источник события вычисляет по действию (`Events::DetectSourceService`), а для
  `recognized_result` и `pay_register` — по форме payload, так как продюсеров у них двое.

## Порты

| Сервис | URL |
|---|---|
| check-manager | http://localhost:8001/admin |
| check-ruler | http://localhost:8002/admin |
| check-register | http://localhost:8003/admin |
| budget-control | http://localhost:8004/admin |
| event-logger | http://localhost:8005/admin |
| RabbitMQ management | http://localhost:15672 (guest/guest) |
| RabbitMQ метрики | http://localhost:15692/metrics |
| Prometheus | http://localhost:9090 |
| Grafana | http://localhost:3000 (просмотр без входа, admin/admin для правок) |

Метрики каждого процесса микросервиса — на порту 9394 внутри сети compose
(`docker compose exec check-manager-sneakers curl -s http://localhost:9394/metrics`), наружу не
проброшены.

## Мониторинг

Конфигурация Prometheus — `prometheus/prometheus.yml`, монтируется в контейнер; после правки
достаточно `curl -X POST http://localhost:9090/-/reload`. Решение описано в ADR-0010.

Размеры очередей приходят от брокера: плагин `rabbitmq_prometheus` включён в RabbitMQ 4.x по
умолчанию. **Разбивку по очередям даёт только `/metrics/detailed`** с явным перечнем семейств
(`queue_coarse_metrics`, `queue_consumer_count`) — обычный `/metrics` агрегирует всё по узлу.
Очереди ошибок размечаются меткой `dead_letter` через `metric_relabel_configs`.

Работоспособность сервисы публикуют сами: `service_up`, `service_dependency_up`,
`service_start_time_seconds` с метками `service` и `process` (`web`, `sneakers`, `jobs`).
Метрика `up` от Prometheus говорит лишь, что процесс отвечает, `service_up` — что доступны
его база и брокер.

Добавляя цель, правь и список `services` в `prometheus/prometheus.yml`: цели перечислены явно,
service discovery в стенде нет. yandex-vision в корневом compose не запущен и в списке
отсутствует — иначе цель висела бы вечно в состоянии down. `relabel_configs` там же срезает порт
из метки `instance` (в подписях панелей он только мешает), а флаг
`--enable-feature=promql-experimental-functions` в docker-compose нужен ради `sort_by_label`
в дашбордах — без него порядок плашек скачет между обновлениями.

**Grafana**: источник данных и дашборды задаются provisioning-файлами (`grafana/provisioning/`),
правки через интерфейс не сохраняются (`allowUiUpdates: false`). Дашборды — не рукописный JSON:
`grafana/dashboards/*.json` собираются скриптом `python3 grafana/build_dashboards.py`, правь
скрипт и перегенерируй, иначе изменения затрёт следующая генерация. Панели ссылаются на источник
данных по фиксированному uid `prometheus`.

Стартовая страница — «Обзор системы» (`GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH` в
docker-compose), ссылки на соседние дашборды лежат в его текстовой панели. Выпадающий список
в шапке собирается по тегу `event-app`, поэтому новый дашборд с этим тегом попадает в навигацию
сам — а вот ссылку в текстовую панель нужно дописать руками.

## Конвенции, о которых легко споткнуться

- **Локализация.** Гема `rails-i18n` в проекте нет. Русская локаль работает за счёт
  `config/initializers/i18n.rb` (подключает `I18n::Backend::Pluralization`) и `config/locales/plurals.rb`
  (правило CLDR). У каждой модели в `activerecord.models` обязателен ключ `other` — ActiveAdmin
  запрашивает название ресурса с дробным `count`, и без `other` страница падает. Форматы дат, чисел
  и подписи пагинации (`views.pagination.*`) заданы вручную в `config/locales/ru.yml`.
- **Ransack и ActiveAdmin.** Доступные для поиска поля перечисляются в константах `PUBLIC_FIELDS` и
  `RANSACK_ASSOCIATIONS` (конкерн `Ransackable`). Колонку типа `uuid` нельзя фильтровать через `_cont`
  (в Postgres нет `LIKE` для uuid) — нужен `ransacker`, приводящий её к тексту.
- **`t(...)` в DSL ActiveAdmin.** Внутри `filter ..., label: proc { ... }` хелпер `t` недоступен
  (контекст `ResourceDSL`) — используй `I18n.t`. Внутри `index`/`show`/`panel` `t` работает.
- **Спеки** пишутся на русском языке в описаниях. `spec/support/rabbitmq.rb` подменяет канал Bunny
  null-объектом, поэтому загрузка воркера в тестах не пытается объявлять очереди.
- **Первичные ключи — uuid**, поэтому `Model.last` возвращает произвольную запись: в тестах
  сортируй явно (`order(:created_at).last`).
- Публикуя тестовое сообщение в живую систему, помни, что реальный routing key разбудит настоящих
  потребителей. Безопасный приём — публиковать с ключом, равным имени очереди сервиса (так делает
  `rake fake_message:start`), либо с заведомо несуществующим ключом.

## Документация

- `docs/adr/` — архитектурные решения (брокер, кто создаёт топики, correlation-id, формат сообщения,
  почта, отказ от TTL и временных ссылок, слой бизнес-логики, очереди ошибок, мониторинг).
  Читай их перед изменением контрактов.
- `docs/asyncapi.yaml` — спецификация обмена, HTML генерируется командой из `readme.md`.
- `readme.md` в корне — обзор и порядок запуска; в каждом микросервисе свой `readme.md`.
