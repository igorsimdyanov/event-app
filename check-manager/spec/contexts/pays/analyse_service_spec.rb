# frozen_string_literal: true

RSpec.describe Pays::AnalyseService do
  let(:message) do
    {
      action: 'recognized_result',
      payload: { file: 'check.jpeg', attachment_id: 'a1', message: 'текст чека' }
    }
  end

  before { allow(RabbitMessages::Send).to receive(:call) }

  it 'отправляет во внешний обменник построенное сообщение анализа платежа' do
    described_class.call(message)

    expect(RabbitMessages::Send).to have_received(:call) do |next_message|
      expect(next_message[:action]).to eq('pay_analyse')
      expect(next_message[:routing_key]).to eq('pay_analyse')
      expect(next_message[:payload]).to include(file: 'check.jpeg', message: 'текст чека')
    end
  end
end
