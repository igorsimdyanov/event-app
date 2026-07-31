# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RabbitmqManager do
  let(:exchange) { instance_double(Bunny::Exchange) }
  let(:queue) { instance_double(Bunny::Queue, bind: nil) }
  let(:channel) { instance_double(Bunny::Channel, queue: queue, exchange: exchange, close: nil) }
  let(:connection) do
    instance_double(Bunny::Session, start: nil, create_channel: channel, close: nil)
  end

  before { allow(Bunny).to receive(:new).and_return(connection) }

  it 'создаёт подключение с настройками RabbitMQ' do
    described_class.call { |_exchange| }
    expect(Bunny).to have_received(:new).with(Settings.rabbitmq.to_hash)
  end

  it 'запускает соединение и открывает канал' do
    described_class.call { |_exchange| }

    expect(connection).to have_received(:start)
    expect(connection).to have_received(:create_channel)
  end

  it 'объявляет устойчивую очередь с dead-letter обменником' do
    described_class.call { |_exchange| }

    expect(channel).to have_received(:queue).with(
      Settings.rabbitmq.outbox_queue,
      hash_including(
        durable: true,
        arguments: {
          'x-dead-letter-exchange' => "#{Settings.rabbitmq.outbox_queue}.error",
          'x-dead-letter-routing-key' => "#{Settings.rabbitmq.outbox_queue}.error"
        }
      )
    )
  end

  it 'объявляет устойчивый topic-обменник' do
    described_class.call { |_exchange| }

    expect(channel).to have_received(:exchange).with(
      Settings.rabbitmq.exchange,
      hash_including(type: Settings.rabbitmq.exchange_type, durable: true)
    )
  end

  it 'связывает очередь с обменником по routing key' do
    described_class.call { |_exchange| }

    expect(queue).to have_received(:bind)
      .with(exchange, hash_including(routing_key: Settings.rabbitmq.routing_key))
  end

  it 'передаёт обменник в блок' do
    expect { |probe| described_class.call(&probe) }.to yield_with_args(exchange)
  end

  it 'закрывает канал и соединение после работы' do
    described_class.call { |_exchange| }

    expect(channel).to have_received(:close)
    expect(connection).to have_received(:close)
  end
end
