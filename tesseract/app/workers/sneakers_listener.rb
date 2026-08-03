class SneakersListener
  include Sneakers::Worker
  include Tracing::Consumer

  ACTION_HANDLERS = {
    recognize: Checks::RecognizeService,
  }.freeze
  QUEUE_NAME = Settings.sneakers.queue
  QUEUE_DEAD_LETTER = "#{Settings.sneakers.queue}.error".freeze
  # Сообщение, отклонённое обработчиком, обменник уводит в очередь ошибок (ADR-0009)
  DEAD_LETTER_ARGUMENTS = {
    'x-dead-letter-exchange' => Settings.rabbitmq.exchange,
    'x-dead-letter-routing-key' => QUEUE_DEAD_LETTER
  }.freeze
  ARGUMENTS = {
    durable: true,
    arguments: DEAD_LETTER_ARGUMENTS
  }.freeze

  from_queue Settings.sneakers.queue, queue_options: { arguments: DEAD_LETTER_ARGUMENTS }

  attr_reader :parsed_message

  # Контекст трассировки едет в заголовках B3 (ADR-0011), поэтому воркеру
  # нужны properties сообщения, а не одно только тело
  def work_with_params(message, delivery_info, metadata)
    parse_message(message)
    trace_message(delivery_info, metadata, parsed_message) { process_message }
    ack!
  rescue StandardError => e
    Rails.logger.error(e.message)
    Rails.logger.error(e.backtrace.join("\n"))
    reject!
  end

  private

  def parse_message(message)
    @parsed_message = JSON.parse(message, symbolize_names: true)
    logger.info("Listener worker - message: #{parsed_message}")
  end

  def process_message
    handler = ACTION_HANDLERS[action&.to_sym]
    raise StandardError, "Action #{action} is not supported" unless handler

    handler.call(parsed_message)
  end

  def action
    parsed_message[:action]
  end
end

RabbitBindQueues.create_for(SneakersListener)
