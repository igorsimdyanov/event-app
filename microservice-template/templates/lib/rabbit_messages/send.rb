module RabbitMessages
  class Send < BaseAmqp
    include Logging
    include Callable

    attr_reader :parsed_message, :routing_key

    def initialize(parsed_message, routing_key=nil)
      super()
      @parsed_message = parsed_message
      @routing_key = routing_key
      @routing_key = parsed_message[:routing_key] unless routing_key
    end

    def call
      initialize_rabbit_message!(parsed_message,
        RabbitMessage::OUTCOME_MESSAGE,
        routing_key)

      publish_exchange(payload_json)

      rabbit_message&.assign_attributes(data: payload_json)
    rescue => e
      log_error(e)
    ensure
      rabbit_message&.save
    end

    private

    # Заголовки B3 берутся у спана публикации: по ним получатель продолжит
    # трассу отправителя, не заглядывая в тело сообщения (ADR-0011)
    def publish_exchange(payload)
      logging_message(payload)
      exchange = find_exchange(EXCHANGE)

      Tracing.producer_span(routing_key, message: payload) do |span|
        exchange.publish(payload.to_json, routing_key: routing_key, headers: span.headers)
      end
    end

    def logging_message(payload)
      message = "messages.answer_send: routing_key: #{routing_key}, payload: #{payload})"
      Rails.logger.info(message)
    end

    def payload_json
      {
        action: 'recognize',
        created_at: Time.now.to_i,
        routing_key: routing_key,
        payload: payload_data
      }
    end

    def payload_data
      {
        file: parsed_message.dig(:payload, :file),
        full_path: parsed_message.dig(:payload, :full_path),
        attachment_id: parsed_message.dig(:payload, :attachment_id),
        initial_message: parsed_message
      }
    end
  end
end
