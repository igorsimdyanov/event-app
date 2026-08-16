# frozen_string_literal: true

RSpec.describe Checks::ApproveService do
  let(:check) { create(:check, approved: false) }

  before { allow(RabbitMessages::Send).to receive(:call) }

  it 'помечает чек одобренным' do
    described_class.call(check.id)
    expect(check.reload.approved).to be(true)
  end

  it 'отправляет чек на регистрацию с ключом pay_register' do
    described_class.call(check.id)

    expect(RabbitMessages::Send).to have_received(:call) do |next_message|
      expect(next_message).to include(action: 'pay_register', routing_key: 'pay_register')
      expect(next_message[:payload]).to include(
        price: check.price,
        attachment_id: check.attachment_id,
        full_path: check.file
      )
    end
  end
end
