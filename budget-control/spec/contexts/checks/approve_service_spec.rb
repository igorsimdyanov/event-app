# frozen_string_literal: true

RSpec.describe Checks::ApproveService do
  let(:check) { create(:check, approved: false) }

  before { allow(RabbitMessages::Send).to receive(:call) }

  it 'помечает чек одобренным' do
    described_class.call(check.id)
    expect(check.reload.approved).to be(true)
  end

  it 'отправляет чек на регистрацию в очередь register.in' do
    described_class.call(check.id)

    expect(RabbitMessages::Send).to have_received(:call) do |next_message, topic|
      expect(next_message[:action]).to eq('pay_register')
      expect(next_message.dig(:payload, :price)).to eq(check.price)
      expect(next_message.dig(:payload, :attachment_id)).to eq(check.attachment_id)
      expect(next_message.dig(:payload, :full_path)).to eq(check.file)
      expect(topic).to eq('register.in')
    end
  end
end
