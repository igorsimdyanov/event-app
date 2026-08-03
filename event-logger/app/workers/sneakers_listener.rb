class SneakersListener
  include Sneakers::Worker

  QUEUE_NAME = Settings.sneakers.queue
  QUEUE_DEAD_LETTER = "#{Settings.sneakers.queue}.error".freeze
  # Маска маршрутных ключей: сервис собирает все события обменника services
  BINDING_KEYS = Array(Settings.sneakers.binding_key).freeze
  # Отклонённые сообщения уходят в очередь ошибок через обменник по умолчанию,
  # а не через services: очередь журнала слушает маску `#` и приняла бы
  # собственное dead-letter-сообщение обратно, зациклив его (ADR-0009)
  DEAD_LETTER_ARGUMENTS = {
    'x-dead-letter-exchange' => '',
    'x-dead-letter-routing-key' => QUEUE_DEAD_LETTER
  }.freeze
  ARGUMENTS = {
    durable: true,
    arguments: DEAD_LETTER_ARGUMENTS
  }.freeze
  UNPARSABLE_ACTION = 'unparsable_message'.freeze
  PG_EXCEPTION = [
    ActiveRecord::ConnectionNotEstablished,
    ActiveRecord::ConnectionTimeoutError,
    ActiveRecord::NoDatabaseError,
    ActiveRecord::StatementInvalid,
    PG::ConnectionBad,
    PG::UnableToSend
  ].freeze

  from_queue Settings.sneakers.queue, queue_options: { arguments: DEAD_LETTER_ARGUMENTS }

  attr_reader :parsed_message, :raw_message, :routing_key

  # Маршрутный ключ доставки берётся из delivery_info: он точнее поля
  # routing_key в конверте и различает ответы, отправленные через reply_to
  def work_with_params(message, delivery_info, _metadata)
    @raw_message = message
    @routing_key = delivery_info&.routing_key
    parse_message(message)
    ActiveRecord::Base.connection_pool.with_connection { register_event }
    ack!
  rescue *PG_EXCEPTION => e
    reconnect_to_database(e)
  rescue StandardError => e
    log_error(e)
    reject!
  end

  private

  def parse_message(message)
    @parsed_message = JSON.parse(message, symbolize_names: true)
    logger.info("Listener worker - message: #{parsed_message}")
  end

  def register_event
    Events::RegisterService.call(parsed_message, routing_key: routing_key)
  end

  def log_error(err)
    Rails.logger.error(err.message)
    Rails.logger.error(err.backtrace.join("\n"))

    register_failed_event(err)
  end

  # Событие фиксируется даже тогда, когда сообщение не удалось разобрать:
  # журнал должен показывать сбои конвейера, а не умалчивать о них
  def register_failed_event(err)
    ActiveRecord::Base.connection_pool.with_connection do
      Events::RegisterService.call(
        parsed_message || unparsable_message,
        routing_key: routing_key,
        error: err
      )
    end
  rescue StandardError => e
    Rails.logger.error("Не удалось зарегистрировать событие с ошибкой: #{e.message}")
  end

  def unparsable_message
    { action: UNPARSABLE_ACTION, payload: { raw: raw_message.to_s } }
  end

  def reconnect_to_database(err)
    Rails.logger.error(err.message)
    sleep(10)
    ActiveRecord::Base.connection.reconnect!
    requeue!
  rescue StandardError => e
    reconnect_to_database(e)
  end
end

RabbitBindQueues.create_for(SneakersListener)
