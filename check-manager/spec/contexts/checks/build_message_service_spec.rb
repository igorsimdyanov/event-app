# frozen_string_literal: true

RSpec.describe Checks::BuildMessageService do
  subject(:result) do
    described_class.call(message: message, routing_key: 'recognize', reply_to: 'recognized_result')
  end

  let(:message) do
    {
      action: 'attachment_registered',
      payload: {
        file: 'check.jpeg',
        full_path: 'attachment/2026-07-31/check.jpeg',
        attachment_id: 'a1b2c3',
        created_at: 1_761_416_041
      }
    }
  end

  it 'устанавливает action равным routing_key' do
    expect(result[:action]).to eq('recognize')
  end

  it 'проставляет routing_key и reply_to' do
    expect(result).to include(routing_key: 'recognize', reply_to: 'recognized_result')
  end

  it 'переносит данные вложения из исходного сообщения в payload' do
    expect(result[:payload]).to eq(
      file: 'check.jpeg',
      full_path: 'attachment/2026-07-31/check.jpeg',
      attachment_id: 'a1b2c3',
      created_at: 1_761_416_041
    )
  end

  it 'проставляет время создания сообщения как unix-таймстамп' do
    expect(result[:created_at]).to be_a(Integer)
  end

  context 'когда reply_to не передан' do
    subject(:result) { described_class.call(message: message, routing_key: 'recognize') }

    it 'оставляет reply_to пустым' do
      expect(result[:reply_to]).to be_nil
    end
  end
end
