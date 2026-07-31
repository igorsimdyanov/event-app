class RecognizerListener
  include Sneakers::Worker
  include RabbitMessages::Logging

  ACTION_HANDLERS = {
    recognized_result: Pays::AnalyseService
  }.freeze
  QUEUE_NAME = Settings.sneakers.recognizer_queue
  ARGUMENTS = {
    durable: true
  }
  PG_EXCEPTION = [
    ActiveRecord::ConnectionNotEstablished,
    ActiveRecord::ConnectionTimeoutError,
    ActiveRecord::NoDatabaseError,
    ActiveRecord::StatementInvalid,
    PG::ConnectionBad,
    PG::UnableToSend
  ].freeze

  from_queue Settings.sneakers.recognizer_queue

  attr_reader :parsed_message

  def work(message)
    parse_message(message)
    ActiveRecord::Base.connection_pool.with_connection { process_message }
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

RabbitBindQueues.create_for(RecognizerListener)
