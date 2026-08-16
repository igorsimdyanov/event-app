# frozen_string_literal: true

class RabbitmqManager
  attr_reader :connection, :channel

  def self.call(&)
    new.call(&)
  end

  def call
    exchange = connect
    yield(exchange)
    close
  end

  private

  def connect
    @connection = Bunny.new(Settings.rabbitmq.to_hash)
    connection.start
    @channel = connection.create_channel
    dead_letter_queue = Settings.rabbitmq.outbox_queue + '.error'
    queue = channel.queue(
      Settings.rabbitmq.outbox_queue,
      durable: true,
      arguments: {
        'x-dead-letter-exchange' => Settings.rabbitmq.exchange,
        'x-dead-letter-routing-key' => dead_letter_queue
      }
    )
    exchange = channel.exchange(
      Settings.rabbitmq.exchange,
      type: Settings.rabbitmq.exchange_type,
      durable: true
    )
    queue.bind(exchange, routing_key: Settings.rabbitmq.routing_key)

    exchange
  end

  def close
    channel.close
    connection.close
  end
end
