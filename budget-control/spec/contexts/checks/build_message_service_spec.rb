# frozen_string_literal: true

RSpec.describe Checks::BuildMessageService do
  subject(:result) { described_class.call(check: check, routing_key: 'pay_register') }

  let(:check) do
    build(:check, file: 'attachment/2026-07-31/check.png', attachment_id: SecureRandom.uuid, price: '250.00')
  end


  it 'устанавливает action равным routing_key' do
    expect(result[:action]).to eq('pay_register')
  end

  it 'проставляет routing_key' do
    expect(result[:routing_key]).to eq('pay_register')
  end

  it 'формирует payload из данных чека' do
    expect(result[:payload]).to eq(
      full_path: check.file,
      attachment_id: check.attachment_id,
      price: check.price
    )
  end

  it 'проставляет время создания сообщения как unix-таймстамп' do
    expect(result[:created_at]).to be_a(Integer)
  end
end
