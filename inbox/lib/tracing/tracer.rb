require_relative '../metrics/process_info'
require_relative 'trace_context'
require_relative 'span'
require_relative 'null_span'
require_relative 'reporter'

# Распределённая трассировка конвейера (ADR-0011). Сервис отмечает две
# вещи: приём сообщения из очереди и публикацию нового, — а связывает их
# контекст B3, который едет в заголовках AMQP-сообщения. Оба вызова
# принимают маршрутный ключ: он даёт спану имя и становится узлом-каналом
# в графе зависимостей Zipkin.
#
#   Tracing.consumer_span(routing_key, headers: metadata.headers,
#                         message: parsed_message) { обработка }
#
#   Tracing.producer_span(routing_key, message: message) do |span|
#     exchange.publish(message.to_json, routing_key: routing_key, headers: span.headers)
#   end
module Tracing
  CURRENT_SPAN_KEY = :tracing_current_span
  ACTION_TAG = 'action'.freeze
  ATTACHMENT_TAG = 'attachment_id'.freeze
  RECEIVE = 'receive'.freeze
  PUBLISH = 'publish'.freeze

  class << self
    def start
      return unless enabled?

      Reporter.start
    end

    # Обработка сообщения, полученного из очереди. Родителя спан берёт из
    # заголовков сообщения, а если их нет — начинает трассу сам
    def consumer_span(routing_key, headers: nil, message: nil, tags: {}, &)
      context = TraceContext.from_headers(headers) || TraceContext.from_message(message)

      record(span(Span::CONSUMER, routing_key, context, message, tags), &)
    end

    # Публикация сообщения. Внутри обработки родителем становится текущий
    # спан потребителя, вне её (админка, планировщик) начинается новая
    # трасса с идентификатором из attachment_id
    def producer_span(routing_key, message: nil, tags: {}, &)
      context = current&.child_context || TraceContext.from_message(message)

      record(span(Span::PRODUCER, routing_key, context, message, tags), &)
    end

    def current
      Thread.current[CURRENT_SPAN_KEY]
    end

    def enabled?
      return false unless Settings.tracing.enabled
      # Как и метрики, трассировка не поднимается в короткоживущих
      # процессах: консоли, rake-задачах и спеках
      return false if Metrics::ProcessInfo.kind.nil?

      true
    end

    private

    # Имя спана складывается из действия и маршрутного ключа —
    # «receive pay_analyse». Тот же ключ уходит в remoteEndpoint: в графе
    # зависимостей он становится узлом между отправителем и получателем
    def span(kind, routing_key, context, message, tags)
      Span.new(name: "#{kind == Span::CONSUMER ? RECEIVE : PUBLISH} #{routing_key}",
               kind: kind,
               context: context,
               remote: remote_for(routing_key),
               tags: message_tags(message).merge(tags))
    end

    # Сервис, для которого граф зависимостей выключен, спанов не лишается:
    # в трассе чека он виден по-прежнему, но рёбер в схеме не порождает.
    # Так из неё убран event-logger: он получает копию каждого сообщения
    # и связал бы себя со всеми каналами разом, спрятав сам конвейер
    def remote_for(routing_key)
      return unless Settings.tracing.dependencies

      routing_key
    end

    # Спан помечается тем, по чему его ищут в Zipkin: действием сообщения
    # и идентификатором вложения — он же идентификатор трассы
    def message_tags(message)
      return {} unless message.is_a?(Hash)

      {
        ACTION_TAG => message[:action] || message['action'],
        ATTACHMENT_TAG => TraceContext.correlation_id(message)
      }
    end

    # Пока текущий спан подменён, всё, что публикуется внутри блока,
    # становится его потомком. Прежнее значение возвращается на место:
    # спаны вкладываются друг в друга
    def record(span)
      return yield(NullSpan.instance) unless Reporter.started?

      previous = current
      Thread.current[CURRENT_SPAN_KEY] = span.start
      begin
        yield span
      rescue StandardError => e
        span.failed(e)
        raise
      ensure
        Thread.current[CURRENT_SPAN_KEY] = previous
        Reporter.report(span.finish)
      end
    end
  end
end
