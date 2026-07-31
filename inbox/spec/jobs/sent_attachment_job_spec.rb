# frozen_string_literal: true

RSpec.describe SentAttachmentJob, type: :job do
  subject(:perform) { described_class.perform_now }

  let(:exchange) { instance_double(Bunny::Exchange, publish: nil) }

  before { allow(RabbitmqManager).to receive(:call).and_yield(exchange) }

  context 'когда есть неотправленные вложения' do
    let!(:attachment) { create(:attachment) }

    it 'открывает соединение с RabbitMQ через RabbitmqManager' do
      perform
      expect(RabbitmqManager).to have_received(:call)
    end

    it 'публикует сообщение в обменник с нужным routing key' do
      perform
      expect(exchange).to have_received(:publish)
        .with(kind_of(String), hash_including(routing_key: Settings.rabbitmq.routing_key))
    end

    it 'публикует сериализованные данные вложения' do
      perform

      expect(exchange).to have_received(:publish) do |payload, _opts|
        parsed = JSON.parse(payload)
        expect(parsed['action']).to eq('attachment_registered')
        expect(parsed.dig('payload', 'attachment_id')).to eq(attachment.id)
        expect(parsed.dig('payload', 'md5')).to eq(attachment.md5)
      end
    end

    it 'помечает вложение как отправленное' do
      expect { perform }.to change { attachment.reload.sent }.from(false).to(true)
    end
  end

  context 'когда есть несколько неотправленных вложений' do
    before { create_list(:attachment, 3) }

    it 'публикует сообщение для каждого из них' do
      perform
      expect(exchange).to have_received(:publish).exactly(3).times
    end
  end

  context 'когда все вложения уже отправлены' do
    let!(:attachment) { create(:attachment, :sent) }

    it 'ничего не публикует повторно' do
      perform
      expect(exchange).not_to have_received(:publish)
    end

    it 'не меняет флаг sent' do
      expect { perform }.not_to change { attachment.reload.sent }.from(true)
    end
  end

  context 'когда неотправленных вложений нет' do
    it 'не публикует сообщений' do
      perform
      expect(exchange).not_to have_received(:publish)
    end
  end
end
