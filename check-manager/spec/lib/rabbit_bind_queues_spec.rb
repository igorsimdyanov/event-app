# frozen_string_literal: true

RSpec.describe RabbitBindQueues do
  let(:exchange) { instance_double(Bunny::Exchange) }
  let(:queue) { instance_double(Bunny::Queue, bind: nil) }
  let(:channel) { instance_double(Bunny::Channel, exchange: exchange, queue: queue) }

  before { allow(RabbitConnectionManager).to receive(:channel).and_return(channel) }

  describe '.create_for' do
    it 'объявляет устойчивый topic-обменник сервисов' do
      described_class.create_for(RecognizerListener)

      expect(channel).to have_received(:exchange)
        .with(Settings.rabbitmq.exchange, hash_including(type: Settings.rabbitmq.exchange_type, durable: true))
    end

    context 'очередь результатов распознавания (RecognizerListener)' do
      it 'объявляет основную очередь воркера' do
        described_class.create_for(RecognizerListener)
        expect(channel).to have_received(:queue).with('recognizer.out', hash_including(durable: true))
      end

      it 'привязывает очередь к обменнику по ключам обработчиков' do
        described_class.create_for(RecognizerListener)
        expect(queue).to have_received(:bind).with(exchange, hash_including(routing_key: :recognized_result))
      end

      it 'уводит отклонённые сообщения в очередь ошибок' do
        described_class.create_for(RecognizerListener)

        expect(channel).to have_received(:queue).with(
          'recognizer.out',
          hash_including(arguments: hash_including(
            'x-dead-letter-exchange' => Settings.rabbitmq.exchange,
            'x-dead-letter-routing-key' => 'recognizer.out.error'
          ))
        )
      end

      it 'объявляет и привязывает очередь ошибок' do
        described_class.create_for(RecognizerListener)

        expect(channel).to have_received(:queue).with('recognizer.out.error', hash_including(durable: true))
        expect(queue).to have_received(:bind).with(exchange, hash_including(routing_key: 'recognizer.out.error'))
      end
    end

    context 'очередь зарегистрированных вложений (InboxListener)' do
      it 'уводит отклонённые сообщения в очередь ошибок' do
        described_class.create_for(InboxListener)

        expect(channel).to have_received(:queue).with(
          'inbox.out',
          hash_including(arguments: hash_including(
            'x-dead-letter-exchange' => Settings.rabbitmq.exchange,
            'x-dead-letter-routing-key' => 'inbox.out.error'
          ))
        )
      end

      it 'дополнительно объявляет dead-letter очередь' do
        described_class.create_for(InboxListener)
        expect(channel).to have_received(:queue).with('inbox.out.error', hash_including(durable: true))
      end

      it 'привязывает основную и dead-letter очереди по соответствующим ключам' do
        described_class.create_for(InboxListener)

        expect(queue).to have_received(:bind).with(exchange, hash_including(routing_key: 'inbox.out.error'))
        expect(queue).to have_received(:bind).with(exchange, hash_including(routing_key: :attachment_registered))
      end
    end
  end
end
