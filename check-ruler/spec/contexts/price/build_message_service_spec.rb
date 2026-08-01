# frozen_string_literal: true

RSpec.describe Price::BuildMessageService do
  let(:message) do
    {
      action: 'pay_analyse',
      payload: {
        file: 'check.png',
        full_path: 'attachment/2026-07-31/check.png',
        attachment_id: 'a1b2c3',
        created_at: 1_761_416_041,
        message: 'СУММА=250.00'
      }
    }
  end

  subject(:result) { described_class.call(message: message, price: 250.0, routing_key: 'pay_register') }

  it 'устанавливает action равным routing_key' do
    expect(result[:action]).to eq('pay_register')
  end

  it 'проставляет routing_key' do
    expect(result[:routing_key]).to eq('pay_register')
  end

  it 'переносит данные вложения и добавляет извлечённую цену в payload' do
    expect(result[:payload]).to eq(
      file: 'check.png',
      full_path: 'attachment/2026-07-31/check.png',
      attachment_id: 'a1b2c3',
      created_at: 1_761_416_041,
      message: 'СУММА=250.00',
      price: 250.0
    )
  end

  it 'проставляет время создания сообщения как unix-таймстамп' do
    expect(result[:created_at]).to be_a(Integer)
  end
end
