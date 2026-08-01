# frozen_string_literal: true

RSpec.describe RabbitMessages::Send do
  let(:exchange) { instance_double(Bunny::Exchange, publish: nil) }
  let(:channel) { instance_double(Bunny::Channel, exchange: exchange) }
  let(:message) do
    {
      action: 'recognized_result',
      routing_key: 'recognized_result',
      payload: { file: 'check.png', message: 'распознанный текст' }
    }
  end

  before { allow(RabbitConnectionManager).to receive(:channel).and_return(channel) }

  it 'публикует сообщение в обменник, используя routing_key из сообщения' do
    described_class.new(message).call

    expect(exchange).to have_received(:publish)
      .with(message.to_json, hash_including(routing_key: 'recognized_result'))
  end

  context 'когда routing_key передан явным аргументом' do
    it 'использует переданный routing_key вместо ключа из сообщения' do
      described_class.new(message, 'explicit_key').call

      expect(exchange).to have_received(:publish)
        .with(message.to_json, hash_including(routing_key: 'explicit_key'))
    end
  end

  context 'когда включён режим-заглушка AMQP' do
    before { allow(Settings.sneakers).to receive(:amqp_stub).and_return(true) }

    it 'не обращается к реальному каналу RabbitMQ' do
      described_class.new(message).call
      expect(RabbitConnectionManager).not_to have_received(:channel)
    end
  end

  context 'когда публикация завершается ошибкой' do
    before { allow(exchange).to receive(:publish).and_raise(StandardError, 'broker down') }

    it 'не пробрасывает исключение наружу' do
      expect { described_class.new(message).call }.not_to raise_error
    end
  end
end
