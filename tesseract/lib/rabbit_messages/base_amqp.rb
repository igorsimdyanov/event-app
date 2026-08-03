module RabbitMessages
  class BaseAmqp
    EXCHANGE = Settings.rabbitmq.exchange.freeze

    private

    def find_exchange(name)
      return AmqpStub.new if Settings.sneakers.amqp_stub

      bunny_channel.exchange(name, passive: true)
    end

    def bunny_channel
      RabbitConnectionManager.channel
    end

    class AmqpStub
      def publish(_payload, **_options)
        Rails.logger.info('Warning!!! Skipping sending AMQP message in dev environment!')
      end
    end
  end
end
