# frozen_string_literal: true

RSpec.describe Pays::BuildMessageService do
  let(:message) do
    {
      action: 'recognized_result',
      payload: {
        file: 'check.jpeg',
        full_path: 'attachment/2026-07-31/check.jpeg',
        attachment_id: 'a1b2c3',
        created_at: 1_761_416_041,
        message: 'Распознанный текст чека'
      }
    }
  end

  subject(:result) { described_class.call(message: message, routing_key: 'pay_analyse') }

  it 'устанавливает action равным routing_key' do
    expect(result[:action]).to eq('pay_analyse')
  end

  it 'проставляет routing_key' do
    expect(result[:routing_key]).to eq('pay_analyse')
  end

  it 'переносит данные вложения вместе с распознанным текстом в payload' do
    expect(result[:payload]).to eq(
      file: 'check.jpeg',
      full_path: 'attachment/2026-07-31/check.jpeg',
      attachment_id: 'a1b2c3',
      created_at: 1_761_416_041,
      message: 'Распознанный текст чека'
    )
  end

  it 'проставляет время создания сообщения как unix-таймстамп' do
    expect(result[:created_at]).to be_a(Integer)
  end

  it 'не добавляет reply_to' do
    expect(result).not_to have_key(:reply_to)
  end
end
