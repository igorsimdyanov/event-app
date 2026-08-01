# frozen_string_literal: true

RSpec.describe Checks::RecognizeService do
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

  let(:s3_client) { instance_double(Aws::S3::Client) }
  let(:s3_response) { double('S3GetObjectOutput', body: StringIO.new('image-bytes')) }
  let(:send_message) { instance_double(RabbitMessages::Send, call: nil) }

  before do
    allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
    allow(s3_client).to receive(:get_object).and_return(s3_response)
    allow(RabbitMessages::Send).to receive(:new).and_return(send_message)
    # Подменяем внешний вызов Tesseract (backtick), оставляя TempfileManager настоящим.
    allow_any_instance_of(described_class).to receive(:`).and_return('Распознанный текст чека')
  end

  it 'скачивает изображение из S3 по полному пути из сообщения' do
    described_class.call(message)

    expect(s3_client).to have_received(:get_object)
      .with(hash_including(bucket: ENV.fetch('S3_BUCKET_NAME'), key: 'attachment/2026-07-31/check.png'))
  end

  it 'запускает tesseract по пути временного файла с распознаванием русского языка' do
    command = nil
    allow_any_instance_of(described_class).to receive(:`) { |_receiver, cmd| command = cmd; 'текст' }

    described_class.call(message)

    expect(command).to match(%r{\Atesseract .+ stdout --oem 1 -l rus\z})
  end

  it 'отправляет следующее сообщение с распознанным текстом по каналу reply_to' do
    described_class.call(message)

    expect(RabbitMessages::Send).to have_received(:new) do |next_message|
      expect(next_message[:action]).to eq('recognized_result')
      expect(next_message[:routing_key]).to eq('recognized_result')
      expect(next_message.dig(:payload, :message)).to eq('Распознанный текст чека')
      expect(next_message.dig(:payload, :attachment_id)).to eq('a1b2c3')
    end
    expect(send_message).to have_received(:call)
  end
end
