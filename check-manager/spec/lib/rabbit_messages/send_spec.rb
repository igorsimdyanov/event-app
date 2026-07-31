# frozen_string_literal: true

RSpec.describe RabbitMessages::Send do
  let(:exchange) { instance_double(Bunny::Exchange, publish: nil) }
  let(:channel) { instance_double(Bunny::Channel, exchange: exchange) }
  let(:message) do
    {
      action: 'recognize',
      routing_key: 'recognize',
      payload: { file: 'check.jpeg', attachment_id: 'a1' }
    }
  end

  before { allow(RabbitConnectionManager).to receive(:channel).and_return(channel) }

  it 'создаёт исходящую запись RabbitMessage' do
    expect { described_class.call(message) }.to change { RabbitMessage.outcome.count }.by(1)
  end

  it 'публикует сообщение в обменник, используя routing_key из сообщения' do
    described_class.call(message)

    expect(exchange).to have_received(:publish)
      .with(message.to_json, hash_including(routing_key: 'recognize'))
  end

  it 'сохраняет тело сообщения в записи' do
    described_class.call(message)

    expect(RabbitMessage.last.data).to eq(message.deep_stringify_keys)
  end

  context 'когда routing_key передан явным аргументом' do
    it 'использует переданный routing_key вместо ключа из сообщения' do
      described_class.call(message, 'explicit_key')

      expect(exchange).to have_received(:publish)
        .with(message.to_json, hash_including(routing_key: 'explicit_key'))
    end
  end

  context 'когда включён режим-заглушка AMQP' do
    before { allow(Settings.sneakers).to receive(:amqp_stub).and_return(true) }

    it 'не обращается к реальному каналу RabbitMQ' do
      described_class.call(message)
      expect(RabbitConnectionManager).not_to have_received(:channel)
    end

    it 'всё равно сохраняет исходящую запись RabbitMessage' do
      expect { described_class.call(message) }.to change { RabbitMessage.outcome.count }.by(1)
    end
  end

  context 'когда публикация завершается ошибкой' do
    before { allow(exchange).to receive(:publish).and_raise(StandardError, 'broker down') }

    it 'не пробрасывает исключение наружу' do
      expect { described_class.call(message) }.not_to raise_error
    end

    it 'помечает запись неуспешной' do
      described_class.call(message)
      expect(RabbitMessage.last).to have_attributes(success: false, error_message: 'broker down')
    end
  end
end
