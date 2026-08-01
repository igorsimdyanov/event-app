# frozen_string_literal: true

RSpec.describe Checks::RegisterService do
  let(:attachment_id) { SecureRandom.uuid }
  let(:message) do
    {
      action: 'budget_check',
      payload: {
        price: '250.00',
        full_path: 'attachment/2026-07-31/check.png',
        attachment_id: attachment_id,
        message: 'СУММА=250.00'
      }
    }
  end

  it 'создаёт запись чека' do
    expect { described_class.call(message) }.to change(Check, :count).by(1)
  end

  it 'сохраняет цену, путь к файлу и идентификатор вложения' do
    described_class.call(message)

    expect(Check.last).to have_attributes(
      price: '250.00',
      file: 'attachment/2026-07-31/check.png',
      attachment_id: attachment_id,
      approved: false
    )
  end
end
