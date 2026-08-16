# frozen_string_literal: true

class SentAttachmentJob < ApplicationJob
  queue_as :default

  def perform(*_args)
    RabbitmqManager.call do |exchange|
      Attachment.not_sent.find_each do |attach|
        publish(exchange, attach)
        attach.update_columns(sent: true)
      end
    end
  end

  private

  # Здесь начинается трасса всей бизнес-транзакции: идентификатором ей
  # служит id вложения — тот же сквозной correlation-id, что поедет
  # по конвейеру (ADR-0004). Дальше сервисы продолжат её по заголовкам
  # B3, которые кладёт в сообщение спан публикации (ADR-0011)
  def publish(exchange, attachment)
    Tracing.producer_span(
      Settings.rabbitmq.routing_key,
      message: trace_context_of(attachment)
    ) do |span|
      exchange.publish(
        AttachmentSerializer.new(attachment).serialize,
        routing_key: Settings.rabbitmq.routing_key,
        headers: span.headers
      )
    end
  end

  # Трассировке от сообщения нужны только действие и correlation-id,
  # поэтому сериализованное тело для неё не разбирается заново
  def trace_context_of(attachment)
    {action: Settings.rabbitmq.routing_key, payload: {attachment_id: attachment.id}}
  end
end
