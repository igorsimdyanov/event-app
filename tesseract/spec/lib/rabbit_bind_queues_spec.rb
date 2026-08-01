# frozen_string_literal: true

RSpec.describe RabbitBindQueues do
  let(:exchange) { instance_double(Bunny::Exchange) }
  let(:queue) { instance_double(Bunny::Queue, bind: nil) }
  let(:channel) { instance_double(Bunny::Channel, exchange: exchange, queue: queue) }

  before { allow(RabbitConnectionManager).to receive(:channel).and_return(channel) }

  describe '.create_for' do
    it 'объявляет устойчивый topic-обменник сервисов' do
      described_class.create_for(SneakersListener)

      expect(channel).to have_received(:exchange)
        .with(Settings.rabbitmq.exchange, hash_including(type: Settings.rabbitmq.exchange_type, durable: true))
    end

    it 'объявляет устойчивую очередь воркера' do
      described_class.create_for(SneakersListener)

      expect(channel).to have_received(:queue).with(SneakersListener::QUEUE_NAME, hash_including(durable: true))
    end

    it 'привязывает очередь к обменнику по ключам обработчиков' do
      described_class.create_for(SneakersListener)

      expect(queue).to have_received(:bind).with(exchange, hash_including(routing_key: :recognize))
    end
  end
end
