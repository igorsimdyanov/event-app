class InboxListener
  include Sneakers::Worker
  include RabbitMessages::Logging

  ACTION_HANDLERS = {
    attachment_registered: Checks::RecognizeService
  }.freeze
  QUEUE_NAME = Settings.sneakers.inbox_queue
  QUEUE_DEAD_LETTER = "#{Settings.sneakers.inbox_queue}.error".freeze
  # Сообщение, отклонённое обработчиком, обменник уводит в очередь ошибок (ADR-0009)
  DEAD_LETTER_ARGUMENTS = {
    'x-dead-letter-exchange' => Settings.rabbitmq.exchange,
    'x-dead-letter-routing-key' => QUEUE_DEAD_LETTER
  }.freeze
  ARGUMENTS = {
    durable: true,
    arguments: DEAD_LETTER_ARGUMENTS
  }.freeze
  PG_EXCEPTION = [
    ActiveRecord::ConnectionNotEstablished,
    ActiveRecord::ConnectionTimeoutError,
    ActiveRecord::NoDatabaseError,
    ActiveRecord::StatementInvalid,
    PG::ConnectionBad,
    PG::UnableToSend
  ].freeze

  from_queue Settings.sneakers.inbox_queue, queue_options: { arguments: DEAD_LETTER_ARGUMENTS }

  attr_reader :parsed_message

  def work(message)
    parse_message(message)
    ActiveRecord::Base.connection_pool.with_connection { process_message }
    ack!
  rescue Net::ReadTimeout, Errno::ECONNRESET => e
    logger.info("Listener worker - requeue: #{parsed_message}")
    requeue!
  rescue *PG_EXCEPTION => e
    reconnect_to_database(e)
  rescue StandardError => e
    log_error(e)
    reject!
  end

  private

  def parse_message(message)
    # raise Net::ReadTimeout, 'Искусственная ошибка'
    @parsed_message = JSON.parse(message, symbolize_names: true)
    logger.info("Listener worker - message: #{parsed_message}")
  end

  def process_message
    initialize_rabbit_message!(
      parsed_message,
      RabbitMessage::INCOME_MESSAGE,
      action)
    handler = ACTION_HANDLERS[action&.to_sym]
    raise StandardError, "Action #{action} is not supported" unless handler

    handler.call(parsed_message)

    rabbit_message.update!(success: true)
  end

  def action
    parsed_message[:action]
  end

  def reconnect_to_database(err)
    log_error(err)
    sleep(10)
    ActiveRecord::Base.connection.reconnect!
    requeue!
  rescue StandardError => e
    reconnect_to_database(e)
  end
end

RabbitBindQueues.create_for(InboxListener)
