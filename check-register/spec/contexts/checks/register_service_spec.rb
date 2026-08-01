# frozen_string_literal: true

RSpec.describe Checks::RegisterService do
  let(:attachment_id) { SecureRandom.uuid }
  let(:message) do
    {
      action: 'pay_register',
      payload: {
        price: '250.00',
        full_path: 'attachment/2026-07-31/check.png',
        attachment_id: attachment_id
      }
    }
  end

  it 'создаёт запись чека' do
    expect { described_class.call(message) }.to change(Check, :count).by(1)
  end

  it 'регистрирует цену и идентификатор вложения из сообщения' do
    described_class.call(message)

    expect(Check.last).to have_attributes(price: '250.00', attachment_id: attachment_id)
  end
end
