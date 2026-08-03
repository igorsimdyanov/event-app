#!/usr/bin/env python3
"""Генератор дашбордов Grafana для стенда event-app.

Дашборды в grafana/dashboards/*.json собираются этим скриптом, а не правятся
руками: панелей много, и одинаковые части (пороги, подписи, легенды) проще
держать в одном месте. После правки — python3 grafana/build_dashboards.py;
Grafana подхватит новые файлы сама в течение 30 секунд.
"""

import io
import json
import os

DS = {"type": "prometheus", "uid": "prometheus"}
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'dashboards')

UP_MAPPINGS = [{
    "type": "value",
    "options": {
        "0": {"text": "Не работает", "color": "red", "index": 0},
        "1": {"text": "Работает", "color": "green", "index": 1},
    },
}]

OK_MAPPINGS = [{
    "type": "value",
    "options": {
        "0": {"text": "Недоступна", "color": "red", "index": 0},
        "1": {"text": "Доступна", "color": "green", "index": 1},
    },
}]


def gp(x, y, w, h):
    return {"x": x, "y": y, "w": w, "h": h}


def target(expr, legend=None, ref="A", instant=False, fmt=None):
    t = {"refId": ref, "expr": expr, "datasource": DS,
         "instant": instant, "range": not instant}
    if legend:
        t["legendFormat"] = legend
    if fmt:
        t["format"] = fmt
    return t


def thresholds(steps):
    return {"mode": "absolute", "steps": steps}


GREEN_ONLY = thresholds([{"color": "green", "value": None}])
RED_OVER_ZERO = thresholds([{"color": "green", "value": None},
                            {"color": "red", "value": 1}])
UP_DOWN = thresholds([{"color": "red", "value": None},
                      {"color": "green", "value": 1}])


def stat(title, targets, pos, *, description=None, mappings=None, thr=GREEN_ONLY,
         unit="short", color_mode="value", text_mode="value_and_name",
         graph_mode="none", decimals=None, no_value=None):
    defaults = {"mappings": mappings or [], "thresholds": thr, "unit": unit,
                "color": {"mode": "thresholds"}}
    if decimals is not None:
        defaults["decimals"] = decimals
    if no_value is not None:
        defaults["noValue"] = no_value
    panel = {
        "type": "stat", "title": title, "gridPos": pos, "datasource": DS,
        "targets": targets,
        "fieldConfig": {"defaults": defaults, "overrides": []},
        "options": {
            "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False},
            "orientation": "auto", "textMode": text_mode, "colorMode": color_mode,
            "graphMode": graph_mode, "justifyMode": "auto", "wideLayout": True,
        },
    }
    if description:
        panel["description"] = description
    return panel


def timeseries(title, targets, pos, *, description=None, unit="short",
               fill=10, style="line", stack=False, minimum=0, decimals=None,
               calcs=("lastNotNull", "max")):
    custom = {
        "drawStyle": style, "lineWidth": 2, "fillOpacity": fill,
        "showPoints": "never", "spanNulls": True, "lineInterpolation": "linear",
    }
    if stack:
        custom["stacking"] = {"mode": "normal", "group": "A"}
    # Иначе на спокойном стенде ось уезжает до 100 при нулевых значениях
    if unit in ("short", "reqps"):
        custom["axisSoftMax"] = 1
    defaults = {"custom": custom, "unit": unit, "color": {"mode": "palette-classic"},
                "thresholds": GREEN_ONLY}
    if minimum is not None:
        defaults["min"] = minimum
    if decimals is not None:
        defaults["decimals"] = decimals
    panel = {
        "type": "timeseries", "title": title, "gridPos": pos, "datasource": DS,
        "targets": targets,
        "fieldConfig": {"defaults": defaults, "overrides": []},
        "options": {
            "legend": {"displayMode": "table", "placement": "bottom",
                       "showLegend": True, "calcs": list(calcs)},
            "tooltip": {"mode": "multi", "sort": "desc"},
        },
    }
    if description:
        panel["description"] = description
    return panel


def table(title, targets, pos, *, description=None, renames=None, excludes=None,
          overrides=None, join_field="queue", sort_by=None):
    exclude = {"Time": True}
    for i in range(1, 6):
        exclude[f"Time {i}"] = True
    exclude.update(excludes or {})
    transformations = []
    if len(targets) > 1:
        transformations.append({"id": "joinByField",
                                "options": {"byField": join_field, "mode": "outer"}})
    transformations.append({"id": "organize",
                            "options": {"excludeByName": exclude,
                                        "renameByName": renames or {},
                                        "indexByName": {}}})
    panel = {
        "type": "table", "title": title, "gridPos": pos, "datasource": DS,
        "targets": targets, "transformations": transformations,
        "fieldConfig": {
            "defaults": {"custom": {"align": "auto", "cellOptions": {"type": "auto"},
                                    "filterable": True},
                         "thresholds": GREEN_ONLY, "color": {"mode": "thresholds"}},
            "overrides": overrides or [],
        },
        "options": {"showHeader": True, "footer": {"show": False, "reducer": ["sum"]},
                    "sortBy": [{"displayName": sort_by, "desc": False}] if sort_by else []},
    }
    if description:
        panel["description"] = description
    return panel


def row(title, y):
    return {"type": "row", "title": title, "gridPos": gp(0, y, 24, 1),
            "collapsed": False, "panels": []}


def text(title, content, pos):
    return {"type": "text", "title": title, "gridPos": pos,
            "options": {"mode": "markdown", "content": content}}


# Выпадающий список в шапке: перейти к соседнему дашборду, не возвращаясь
# на главную. Собирается по тегу, поэтому новый дашборд с тем же тегом
# попадает в навигацию сам
NAVIGATION = [{
    "type": "dashboards", "title": "Дашборды", "tags": ["event-app"],
    "asDropdown": True, "icon": "external link", "includeVars": False,
    "keepTime": True, "targetBlank": False, "url": "", "tooltip": "",
}]


def dashboard(uid, title, panels, *, description="", refresh="30s",
              time_from="now-1h", templating=None):
    return {
        "uid": uid, "title": title, "description": description,
        "tags": ["event-app"], "timezone": "browser", "editable": True,
        "schemaVersion": 39, "version": 1, "refresh": refresh,
        "time": {"from": time_from, "to": "now"},
        "templating": {"list": templating or []},
        "links": NAVIGATION,
        "panels": panels,
        "annotations": {"list": []},
    }


def color_override(name, color):
    return {"matcher": {"id": "byName", "options": name},
            "properties": [{"id": "color",
                            "value": {"mode": "fixed", "fixedColor": color}}]}


# --------------------------------------------------------------------------
# 1. Обзор системы
# --------------------------------------------------------------------------
NAVIGATION_PANEL = """
**[Микросервисы](/d/event-app-services)** — какой процесс не работает &nbsp;·&nbsp;
**[Очереди ошибок](/d/event-app-dead-letters)** — где застряли сообщения &nbsp;·&nbsp;
**[Очереди детально](/d/event-app-queues)** — что происходит с конкретной очередью &nbsp;·&nbsp;
**[Брокер RabbitMQ](/d/event-app-rabbitmq)** — здоров ли сам брокер

Стенд: [RabbitMQ](http://localhost:15672) &nbsp;·&nbsp; [Prometheus](http://localhost:9090) &nbsp;·&nbsp;
[Zipkin](http://localhost:9411) — путь одного чека во времени &nbsp;·&nbsp;
панели сервисов: [check-manager](http://localhost:8001/admin) &nbsp;·&nbsp;
[check-ruler](http://localhost:8002/admin) &nbsp;·&nbsp;
[check-register](http://localhost:8003/admin) &nbsp;·&nbsp;
[budget-control](http://localhost:8004/admin) &nbsp;·&nbsp;
[event-logger](http://localhost:8005/admin)
""".strip()

overview = dashboard(
    "event-app-overview", "Обзор системы",
    description="Сводка состояния конвейера обработки чеков: процессы, очереди, поток сообщений.",
    panels=[
        text("Куда смотреть дальше", NAVIGATION_PANEL, gp(0, 0, 24, 4)),

        stat("Процессы не отвечают",
             [target('count(up{job="services"} == 0) or vector(0)')],
             gp(0, 4, 6, 4), thr=RED_OVER_ZERO, text_mode="value",
             color_mode="background",
             description="Цели Prometheus, с которых не удалось собрать метрики."),
        stat("Процессы с недоступными зависимостями",
             [target('count(service_up == 0) or vector(0)')],
             gp(6, 4, 6, 4), thr=RED_OVER_ZERO, text_mode="value",
             color_mode="background",
             description="Процесс отвечает, но его база или брокер недоступны."),
        stat("Сообщений в очередях ошибок",
             [target('sum(rabbitmq_detailed_queue_messages{dead_letter="true"})')],
             gp(12, 4, 6, 4), thr=RED_OVER_ZERO, text_mode="value",
             color_mode="background",
             description="Отклонённые сообщения, ожидающие ручного разбора (ADR-0009)."),
        stat("Сообщений в рабочих очередях",
             [target('sum(rabbitmq_detailed_queue_messages{dead_letter="false"})')],
             gp(18, 4, 6, 4), text_mode="value", color_mode="background",
             description="Ненулевое значение при работающих потребителях — сообщения в обработке."),

        stat("Работоспособность процессов",
             [target('sort_by_label(up{job="services"}, "instance")',
                     "{{instance}}", instant=True)],
             gp(0, 8, 24, 5), mappings=UP_MAPPINGS, thr=UP_DOWN,
             color_mode="background",
             description="Отвечает ли процесс на сбор метрик. Подробности — на дашборде «Микросервисы»."),

        timeseries("Поток сообщений через брокер",
                   [target('sum(rate(rabbitmq_global_messages_received_total[$__rate_interval]))',
                           "принято от издателей", "A"),
                    target('sum(rate(rabbitmq_global_messages_routed_total[$__rate_interval]))',
                           "разложено по очередям", "B"),
                    target('sum(rate(rabbitmq_global_messages_delivered_total[$__rate_interval]))',
                           "выдано потребителям", "C"),
                    target('sum(rate(rabbitmq_global_messages_acknowledged_total[$__rate_interval]))',
                           "подтверждено", "D")],
                   gp(0, 13, 12, 8), unit="reqps", decimals=2,
                   description="Сообщений в секунду. Обменник topic копирует сообщение каждому подписчику, поэтому «разложено» обычно больше «принято»."),

        timeseries("Глубина рабочих очередей",
                   [target('rabbitmq_detailed_queue_messages{dead_letter="false"}', "{{queue}}")],
                   gp(12, 13, 12, 8),
                   description="Растущая очередь означает, что потребитель не успевает или упал."),

        table("Очереди без потребителей",
              [target('rabbitmq_detailed_queue_consumers == 0', instant=True, fmt="table")],
              gp(0, 21, 12, 7),
              description="Сообщения в такой очереди никто не заберёт. Для очередей ошибок это норма, для рабочих — нет.",
              excludes={"__name__": True, "job": True, "instance": True,
                        "vhost": True, "Value": True},
              renames={"queue": "Очередь", "dead_letter": "Очередь ошибок"},
              sort_by="Очередь"),

        timeseries("Сообщения в очередях ошибок",
                   [target('rabbitmq_detailed_queue_messages{dead_letter="true"}', "{{queue}}")],
                   gp(12, 21, 12, 7), stack=True,
                   description="Подробности — на дашборде «Очереди ошибок»."),
    ])

# --------------------------------------------------------------------------
# 2. Микросервисы
# --------------------------------------------------------------------------
services = dashboard(
    "event-app-services", "Микросервисы",
    description="Работоспособность процессов микросервисов: у сервиса отдельно живут веб-панель, потребитель Sneakers и планировщик заданий.",
    panels=[
        stat("Процесс отвечает",
             [target('sort_by_label(up{job="services"}, "instance")',
                     "{{instance}}", instant=True)],
             gp(0, 0, 24, 6), mappings=UP_MAPPINGS, thr=UP_DOWN,
             color_mode="background",
             description="Метрика up самого Prometheus: удалось ли собрать метрики с процесса. Ноль означает, что процесс не запущен или завис."),

        stat("Все зависимости доступны",
             [target('sort_by_label(service_up, "service", "process")',
                     "{{service}} / {{process}}", instant=True)],
             gp(0, 6, 24, 6), mappings=UP_MAPPINGS, thr=UP_DOWN,
             color_mode="background",
             description="Метрика service_up самого процесса: единица, если доступны и база, и брокер. Процесс может отвечать, но не мочь работать."),

        stat("Зависимости по отдельности",
             [target('sort_by_label(service_dependency_up, "service", "process", "dependency")',
                     "{{service}} / {{process}}: {{dependency}}", instant=True)],
             gp(0, 12, 24, 7), mappings=OK_MAPPINGS, thr=UP_DOWN,
             color_mode="background",
             description="У tesseract и yandex-vision своей базы нет — только брокер."),

        timeseries("История доступности",
                   [target('up{job="services"}', "{{instance}}")],
                   gp(0, 19, 12, 8), minimum=0,
                   description="Провалы показывают перезапуски и падения процессов."),

        table("Время работы процессов",
              [target('time() - service_start_time_seconds', instant=True, fmt="table")],
              gp(12, 19, 12, 8),
              description="Недавно перезапущенный процесс виден по малому времени работы.",
              excludes={"__name__": True, "job": True, "instance": True},
              renames={"service": "Сервис", "process": "Процесс", "Value": "Работает"},
              join_field="service", sort_by="Сервис",
              overrides=[{"matcher": {"id": "byName", "options": "Работает"},
                          "properties": [{"id": "unit", "value": "s"},
                                         {"id": "custom.cellOptions",
                                          "value": {"type": "color-text"}}]}]),
    ])

# --------------------------------------------------------------------------
# 3. Очереди ошибок
# --------------------------------------------------------------------------
dead_letters = dashboard(
    "event-app-dead-letters", "Очереди ошибок",
    description="Парные очереди <очередь>.error (ADR-0009): сюда попадают сообщения, отклонённые обработчиком. Возврат — ручная операция из консоли сервиса.",
    panels=[
        stat("Всего сообщений в очередях ошибок",
             [target('sum(rabbitmq_detailed_queue_messages{dead_letter="true"})')],
             gp(0, 0, 8, 5), thr=RED_OVER_ZERO, text_mode="value",
             color_mode="background",
             description="Любое ненулевое значение требует разбора: чек выпал из конвейера."),
        stat("Очередей ошибок с сообщениями",
             [target('count(rabbitmq_detailed_queue_messages{dead_letter="true"} > 0) or vector(0)')],
             gp(8, 0, 8, 5), thr=RED_OVER_ZERO, text_mode="value",
             color_mode="background"),
        stat("Отклонений в минуту",
             [target('sum(rate(rabbitmq_global_messages_dead_lettered_rejected_total[$__rate_interval])) * 60')],
             gp(16, 0, 8, 5), thr=RED_OVER_ZERO, text_mode="value",
             color_mode="background", decimals=2,
             description="Темп появления новых отклонённых сообщений во всём брокере."),

        timeseries("Сообщения в очередях ошибок",
                   [target('rabbitmq_detailed_queue_messages{dead_letter="true"}', "{{queue}}")],
                   gp(0, 5, 24, 9), stack=True,
                   description="Каждая линия — отдельная очередь ошибок. Значение не убывает само: сообщения ждут ручного возврата."),

        table("Состояние очередей ошибок",
              [target('sum by (queue) (rabbitmq_detailed_queue_messages{dead_letter="true"})',
                      instant=True, fmt="table", ref="A"),
               target('sum by (queue) (rabbitmq_detailed_queue_messages_ready{dead_letter="true"})',
                      instant=True, fmt="table", ref="B"),
               target('sum by (queue) (rabbitmq_detailed_queue_consumers{dead_letter="true"})',
                      instant=True, fmt="table", ref="C")],
              gp(0, 14, 24, 8),
              description="Разбор выполняется в консоли сервиса, которому принадлежит очередь: рецепты — в docs/adr/0009-dead-letter-queues.md",
              renames={"queue": "Очередь ошибок", "Value #A": "Всего сообщений",
                       "Value #B": "Готовы к выдаче", "Value #C": "Потребители"},
              sort_by="Очередь ошибок",
              overrides=[{"matcher": {"id": "byName", "options": "Всего сообщений"},
                          "properties": [
                              {"id": "custom.cellOptions",
                               "value": {"type": "color-background", "mode": "gradient"}},
                              {"id": "thresholds", "value": RED_OVER_ZERO}]}]),

        timeseries("Темп отклонений",
                   [target('sum(rate(rabbitmq_global_messages_dead_lettered_rejected_total[$__rate_interval]))',
                           "отклонено обработчиком")],
                   gp(0, 22, 24, 7), unit="reqps", decimals=3,
                   description="Всплеск означает, что конвейер начал сыпаться прямо сейчас."),
    ])

# --------------------------------------------------------------------------
# 4. Очереди детально
# --------------------------------------------------------------------------
queue_variable = [{
    "name": "queue", "label": "Очередь", "type": "query", "datasource": DS,
    "query": {"query": "label_values(rabbitmq_detailed_queue_messages, queue)",
              "refId": "queue"},
    "refresh": 2, "multi": True, "includeAll": True, "allValue": ".*",
    "current": {"text": ["All"], "value": ["$__all"], "selected": True},
    "sort": 1, "options": [], "hide": 0,
}]

queues = dashboard(
    "event-app-queues", "Очереди детально",
    description="Метрики /metrics/detailed брокера: глубина очереди, готовность к выдаче, выданные без подтверждения сообщения и число подписчиков.",
    templating=queue_variable,
    panels=[
        table("Сводка по очередям",
              [target('sum by (queue) (rabbitmq_detailed_queue_messages{queue=~"$queue"})',
                      instant=True, fmt="table", ref="A"),
               target('sum by (queue) (rabbitmq_detailed_queue_messages_ready{queue=~"$queue"})',
                      instant=True, fmt="table", ref="B"),
               target('sum by (queue) (rabbitmq_detailed_queue_messages_unacked{queue=~"$queue"})',
                      instant=True, fmt="table", ref="C"),
               target('sum by (queue) (rabbitmq_detailed_queue_consumers{queue=~"$queue"})',
                      instant=True, fmt="table", ref="D")],
              gp(0, 0, 24, 9),
              description="Глубина = готовы к выдаче + выданы без подтверждения.",
              renames={"queue": "Очередь", "Value #A": "Глубина",
                       "Value #B": "Готовы к выдаче",
                       "Value #C": "Выданы без подтверждения",
                       "Value #D": "Потребители"},
              sort_by="Очередь",
              overrides=[{"matcher": {"id": "byName", "options": "Потребители"},
                          "properties": [
                              {"id": "custom.cellOptions",
                               "value": {"type": "color-text"}},
                              {"id": "thresholds",
                               "value": thresholds([{"color": "red", "value": None},
                                                    {"color": "green", "value": 1}])}]}]),

        timeseries("Глубина очереди",
                   [target('rabbitmq_detailed_queue_messages{queue=~"$queue"}', "{{queue}}")],
                   gp(0, 9, 12, 8),
                   description="rabbitmq_detailed_queue_messages — все сообщения очереди."),

        timeseries("Готовы к выдаче",
                   [target('rabbitmq_detailed_queue_messages_ready{queue=~"$queue"}', "{{queue}}")],
                   gp(12, 9, 12, 8),
                   description="rabbitmq_detailed_queue_messages_ready — ждут свободного потребителя."),

        timeseries("Выданы без подтверждения",
                   [target('rabbitmq_detailed_queue_messages_unacked{queue=~"$queue"}', "{{queue}}")],
                   gp(0, 17, 12, 8),
                   description="rabbitmq_detailed_queue_messages_unacked — потребитель взял сообщение, но ещё не сделал ack!. Застрявшее здесь сообщение означает зависший обработчик."),

        timeseries("Потребители очереди",
                   [target('rabbitmq_detailed_queue_consumers{queue=~"$queue"}', "{{queue}}")],
                   gp(12, 17, 12, 8), decimals=0,
                   description="rabbitmq_detailed_queue_consumers — сколько воркеров подписано. Ноль на рабочей очереди — потребитель отвалился."),
    ])

# --------------------------------------------------------------------------
# 5. Брокер RabbitMQ
# --------------------------------------------------------------------------
rabbitmq = dashboard(
    "event-app-rabbitmq", "Брокер RabbitMQ",
    description="Состояние самого брокера: соединения, потоки сообщений, ресурсы узла.",
    panels=[
        stat("Соединения", [target('rabbitmq_connections')], gp(0, 0, 4, 4),
             text_mode="value", color_mode="background"),
        stat("Каналы", [target('rabbitmq_channels')], gp(4, 0, 4, 4),
             text_mode="value", color_mode="background"),
        stat("Потребители", [target('rabbitmq_consumers')], gp(8, 0, 4, 4),
             text_mode="value", color_mode="background"),
        stat("Очереди", [target('rabbitmq_queues')], gp(12, 0, 4, 4),
             text_mode="value", color_mode="background"),
        stat("Память узла", [target('rabbitmq_process_resident_memory_bytes')],
             gp(16, 0, 4, 4), unit="bytes", text_mode="value", color_mode="background"),
        stat("Брокер работает", [target('rabbitmq_erlang_uptime_seconds')],
             gp(20, 0, 4, 4), unit="s", text_mode="value", color_mode="background"),

        timeseries("Сообщения: приём и маршрутизация",
                   [target('sum(rate(rabbitmq_global_messages_received_total[$__rate_interval]))',
                           "принято от издателей", "A"),
                    target('sum(rate(rabbitmq_global_messages_routed_total[$__rate_interval]))',
                           "разложено по очередям", "B")],
                   gp(0, 4, 12, 8), unit="reqps", decimals=2,
                   description="Обменник services — topic: одно сообщение может попасть в несколько очередей, поэтому «разложено» обычно больше «принято» (копию получает и event-logger)."),

        timeseries("Сообщения: выдача и подтверждение",
                   [target('sum(rate(rabbitmq_global_messages_delivered_total[$__rate_interval]))',
                           "выдано потребителям", "A"),
                    target('sum(rate(rabbitmq_global_messages_acknowledged_total[$__rate_interval]))',
                           "подтверждено (ack)", "B"),
                    target('sum(rate(rabbitmq_global_messages_redelivered_total[$__rate_interval]))',
                           "выдано повторно", "C")],
                   gp(12, 4, 12, 8), unit="reqps", decimals=2,
                   description="Повторная выдача растёт, когда обработчик делает requeue! — например, при обрыве связи с базой."),

        timeseries("Сообщения без адресата",
                   [target('sum(rate(rabbitmq_global_messages_unroutable_dropped_total[$__rate_interval]))',
                           "отброшено", "A"),
                    target('sum(rate(rabbitmq_global_messages_unroutable_returned_total[$__rate_interval]))',
                           "возвращено издателю", "B")],
                   gp(0, 12, 12, 8), unit="reqps", decimals=3,
                   description="Сообщение с маршрутным ключом, который никто не слушает, брокер молча выбрасывает. Частая причина — опечатка в action или очередь, которую ещё никто не объявил."),

        stat("Аварийные ограничения",
             [target('rabbitmq_alarms_free_disk_space_watermark', "диск", "A", instant=True),
              target('rabbitmq_alarms_memory_used_watermark', "память", "B", instant=True),
              target('rabbitmq_alarms_file_descriptor_limit', "файловые дескрипторы", "C", instant=True)],
             gp(12, 12, 12, 8),
             mappings=[{"type": "value", "options": {
                 "0": {"text": "Норма", "color": "green", "index": 0},
                 "1": {"text": "Тревога", "color": "red", "index": 1}}}],
             thr=RED_OVER_ZERO, color_mode="background",
             description="Единица означает, что брокер перестал принимать сообщения от издателей до устранения причины."),

        timeseries("Свободное место на диске",
                   [target('rabbitmq_disk_space_available_bytes', "доступно", "A"),
                    target('rabbitmq_disk_space_available_limit_bytes', "порог тревоги", "B")],
                   gp(0, 20, 12, 7), unit="bytes", minimum=None),

        timeseries("Память узла",
                   [target('rabbitmq_process_resident_memory_bytes', "занято", "A"),
                    target('rabbitmq_resident_memory_limit_bytes', "порог тревоги", "B")],
                   gp(12, 20, 12, 7), unit="bytes", minimum=None),
    ])


for name, board in [("overview", overview), ("services", services),
                    ("dead-letters", dead_letters), ("queues", queues),
                    ("rabbitmq", rabbitmq)]:
    path = os.path.join(OUT, f"{name}.json")
    with io.open(path, "w", encoding="utf-8") as handle:
        json.dump(board, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    print("записан", path)
