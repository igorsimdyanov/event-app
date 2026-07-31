# frozen_string_literal: true

RSpec.describe Checks::RecognizeService do
  let(:message) do
    {
      action: 'attachment_registered',
      payload: { file: 'check.jpeg', full_path: 'a/check.jpeg', attachment_id: 'a1', created_at: 111 }
    }
  end

  before { allow(RabbitMessages::Send).to receive(:call) }

  it 'отправляет во внешний обменник построенное сообщение распознавания' do
    described_class.call(message)

    expect(RabbitMessages::Send).to have_received(:call) do |next_message|
      expect(next_message[:action]).to eq('recognize')
      expect(next_message[:reply_to]).to eq('recognized_result')
      expect(next_message[:payload]).to include(file: 'check.jpeg', attachment_id: 'a1')
    end
  end
end
