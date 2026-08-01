# frozen_string_literal: true

RSpec.describe YandexVisionManager do
  let(:path) { Rails.root.join('spec/fixtures/check.png').to_s }
  let(:response) { instance_double(HTTParty::Response) }

  before { allow(described_class).to receive(:post).and_return(response) }

  it 'возвращает ответ Yandex Vision OCR' do
    expect(described_class.call(path, iam_token: 'test-token')).to eq(response)
  end

  it 'обращается к эндпоинту распознавания текста' do
    described_class.call(path, iam_token: 'test-token')
    expect(described_class).to have_received(:post).with('/ocr/v1/recognizeText', anything)
  end

  it 'передаёт заголовки авторизации и идентификатор каталога' do
    described_class.call(path, iam_token: 'test-token')

    expect(described_class).to have_received(:post) do |_url, options|
      expect(options[:headers]).to include(
        'Content-Type' => 'application/json',
        'Authorization' => 'Bearer test-token',
        'x-folder-id' => 'b1gdtl2rf29n03bd49nn'
      )
    end
  end

  it 'кодирует содержимое файла в base64 и описывает параметры распознавания' do
    described_class.call(path, iam_token: 'test-token')

    expect(described_class).to have_received(:post) do |_url, options|
      body = JSON.parse(options[:body])
      expect(body['content']).to eq(Base64.strict_encode64(File.read(path)))
      expect(body['mimeType']).to eq('png')
      expect(body['model']).to eq('page')
      expect(body['languageCodes']).to eq(%w[en ru])
    end
  end
end
