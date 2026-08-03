# 9: Очереди недоставленных сообщений

Дата: 2026-08-02

## Статус

Принят

## Проблема

Обработчик сообщения может завершиться ошибкой: пришло сообщение с неизвестным
действием, распознаватель не смог скачать файл из S3, база данных отвергла
запись. Во всех этих случаях воркер вызывает `reject!`, и брокер удаляет
сообщение из очереди.

До сих пор dead-letter-очередь была настроена только у `inbox.out`
(микросервис check-manager). У остальных шести очередей её не было, поэтому
отклонённое сообщение исчезало бесследно: товарный чек молча выпадал из
конвейера, и узнать об этом можно было только по отсутствию записи в
check-register. Журнал `rabbit_messages` фиксировал факт ошибки, но само
сообщение — единственный носитель данных о чеке — терялось, и повторить
обработку было нечем.

## Решение

Каждая очередь конвейера получает парную очередь недоставленных сообщений
с именем `<очередь>.error`:

| очередь | очередь ошибок |
|---|---|
| `inbox.out` | `inbox.out.error` |
| `tesseract.in` | `tesseract.in.error` |
| `yandex_vision.in` | `yandex_vision.in.error` |
| `recognizer.out` | `recognizer.out.error` |
| `check_manager.out` | `check_manager.out.error` |
| `budget_control.in` | `budget_control.in.error` |
| `register.in` | `register.in.error` |
| `event_logger.in` | `event_logger.in.error` |

Основная очередь объявляется с аргументами `x-dead-letter-exchange` и
`x-dead-letter-routing-key`, очередь ошибок — как обычная устойчивая очередь.
И то, и другое объявляет сервис-потребитель (ADR-0003) — константы
`QUEUE_DEAD_LETTER`, `DEAD_LETTER_ARGUMENTS` и `ARGUMENTS` в классе воркера,
объявление и привязка — в `RabbitBindQueues`.

Отклонённое сообщение уходит в обменник `services` по ключу, равному имени
очереди ошибок, и оседает в ней. Побочный полезный эффект: очередь журнала
событий привязана к обменнику маской `#`, поэтому event-logger видит и
фиксирует каждый уход сообщения в dead-letter — сбои конвейера видны в
общей хронологии по чеку.

**Исключение — сам event-logger.** Его очередь слушает `#`, то есть приняла бы
обратно и собственное dead-letter-сообщение: отклонённое сообщение вернулось бы
в `event_logger.in`, было бы отклонено снова и зациклилось, размножаясь в
очереди ошибок. Поэтому у event-logger `x-dead-letter-exchange` пуст —
сообщение направляется в `event_logger.in.error` через обменник по умолчанию,
минуя `services`, а сама очередь ошибок к `services` не привязывается.

Повторная отправка (retry) сообщений автоматически не выполняется: решение о
возврате принимает человек, разобравшись в причине ошибки.

## Как вернуть сообщения из очереди ошибок

Разбор выполняется в консоли того микросервиса, которому принадлежит очередь
(`docker compose exec check-register bin/rails c`). Соединение с брокером
доступно через `RabbitConnectionManager`.

**Посмотреть, что накопилось, ничего не изымая.** `manual_ack: true` вместе с
`nack` возвращает сообщение в очередь:

```ruby
channel = RabbitConnectionManager.channel
queue = channel.queue('register.in.error', durable: true)

puts queue.message_count

delivery_info, _properties, payload = queue.pop(manual_ack: true)
puts JSON.pretty_generate(JSON.parse(payload))
channel.nack(delivery_info.delivery_tag, false, true)
```

**Вернуть все сообщения в рабочую очередь.** Публикация идёт через обменник по
умолчанию с маршрутным ключом, равным имени очереди: сообщение попадёт ровно в
неё и не размножится по другим подписчикам обменника `services`.

```ruby
channel = RabbitConnectionManager.channel
dead_letter = channel.queue('register.in.error', durable: true)

dead_letter.message_count.times do
  delivery_info, _properties, payload = dead_letter.pop(manual_ack: true)
  break unless payload

  channel.default_exchange.publish(payload, routing_key: 'register.in', persistent: true)
  channel.ack(delivery_info.delivery_tag)
end
```

Порядок важен: `ack` подтверждается только после успешной публикации, иначе
сообщение будет потеряно при обрыве соединения.

**Вернуть сообщение в конвейер целиком.** Если нужно, чтобы сообщение снова
прошло штатную маршрутизацию (и попало ко всем подписчикам ключа, включая
журнал событий), публикуем в `services` с исходным маршрутным ключом:

```ruby
message = JSON.parse(payload, symbolize_names: true)
exchange = channel.exchange(Settings.rabbitmq.exchange, type: 'topic', durable: true, passive: true)
exchange.publish(payload, routing_key: message[:routing_key], persistent: true)
```

**Отбросить разобранные сообщения.** Когда возвращать нечего (например,
сообщение с неизвестным действием), очередь очищается целиком:

```ruby
channel.queue('register.in.error', durable: true).purge
```

## Заключение

Отклонённые сообщения не теряются: каждая очередь имеет парную `<очередь>.error`,
объявляемую потребителем вместе с основной. Возврат сообщений — ручная операция
через консоль микросервиса; автоматический retry не вводим, чтобы не зациклить
сообщение, которое падает по неустранимой причине.

Плата за решение: очереди ошибок растут молча — за их наполнением нужно следить
через панель RabbitMQ (http://localhost:15672) или журнал событий event-logger,
где такие сообщения видны по маршрутному ключу, оканчивающемуся на `.error`.

Изменение аргументов очереди задним числом невозможно: RabbitMQ отвергает
повторное объявление существующей очереди с другими параметрами
(`PRECONDITION_FAILED`). Поэтому при добавлении dead-letter к уже работающей
очереди её нужно удалить и дать сервису создать заново, предварительно
сохранив накопленные сообщения.
