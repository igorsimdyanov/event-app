# frozen_string_literal: true

RSpec.describe Checks::BuildMessageService do
  let(:message) do
    {
      action: 'recognize',
      reply_to: 'recognized_result',
      payload: {
        file: 'check.png',
        full_path: 'attachment/2026-07-31/check.png',
        attachment_id: 'a1b2c3',
        created_at: 1_761_416_041
      }
    }
  end

  subject(:result) do
    described_class.call(message: message, recognize_text: 'Распознанный текст чека', routing_key: 'recognized_result')
  end

  it 'устанавливает action равным routing_key' do
    expect(result[:action]).to eq('recognized_result')
  end

  it 'проставляет routing_key' do
    expect(result[:routing_key]).to eq('recognized_result')
  end

  it 'переносит данные вложения и добавляет распознанный текст в payload' do
    expect(result[:payload]).to eq(
      file: 'check.png',
      full_path: 'attachment/2026-07-31/check.png',
      attachment_id: 'a1b2c3',
      created_at: 1_761_416_041,
      message: 'Распознанный текст чека'
    )
  end

  it 'проставляет время создания сообщения как unix-таймстамп' do
    expect(result[:created_at]).to be_a(Integer)
  end
end
