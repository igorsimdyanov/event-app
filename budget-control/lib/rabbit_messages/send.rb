module RabbitMessages
  class Send < BaseAmqp
    include Logging
    include Callable

    attr_reader :message, :routing_key

    def initialize(message, routing_key = nil)
      super()
      @message = message
      @routing_key = routing_key
      @routing_key = message[:routing_key] unless routing_key
    end

    def call
      initialize_rabbit_message!(message,
        RabbitMessage::OUTCOME_MESSAGE,
        routing_key)

      publish_exchange(message)

      rabbit_message&.assign_attributes(data: message)
    rescue => e
      log_error(e)
    ensure
      rabbit_message&.save
    end

    private

    # Заголовки B3 берутся у спана публикации: по ним получатель продолжит
    # трассу отправителя, не заглядывая в тело сообщения (ADR-0011)
    def publish_exchange(payload)
      exchange = find_exchange(EXCHANGE)

      Tracing.producer_span("publish #{routing_key}", message: payload) do |span|
        exchange.publish(payload.to_json, routing_key: routing_key, headers: span.headers)
      end
    end
  end
end
