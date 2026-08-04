module RabbitMessages
  class Send < BaseAmqp
    attr_reader :message, :routing_key

    def initialize(message, routing_key = nil)
      super()
      @message = message
      @routing_key = routing_key
      @routing_key = message[:routing_key] unless routing_key
    end

    def call
      publish_exchange(message)
    rescue => e
      Rails.logger.error(e.message)
      Rails.logger.error(e.backtrace.join("\n"))
    end

    private

    # Заголовки B3 берутся у спана публикации: по ним получатель продолжит
    # трассу отправителя, не заглядывая в тело сообщения (ADR-0011)
    def publish_exchange(payload)
      exchange = find_exchange(EXCHANGE)

      Tracing.producer_span(routing_key, message: payload) do |span|
        exchange.publish(payload.to_json, routing_key: routing_key, headers: span.headers)
      end
    end
  end
end
