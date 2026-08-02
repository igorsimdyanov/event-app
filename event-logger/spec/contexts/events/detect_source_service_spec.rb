# frozen_string_literal: true

RSpec.describe Events::DetectSourceService do
  def message(action, payload = {})
    { action: action, payload: payload.merge(attachment_id: SecureRandom.uuid) }
  end

  it 'относит регистрацию вложения к inbox' do
    expect(described_class.call(message('attachment_registered'))).to eq('inbox')
  end

  it 'относит команду распознавания к оркестратору' do
    expect(described_class.call(message('recognize'))).to eq('check-manager')
  end

  it 'относит команду анализа стоимости к оркестратору' do
    expect(described_class.call(message('pay_analyse'))).to eq('check-manager')
  end

  it 'относит отправку на бюджетный контроль к check-ruler' do
    expect(described_class.call(message('budget_check', price: 1500.0))).to eq('check-ruler')
  end

  describe 'результат распознавания' do
    it 'считает источником tesseract, если текст пришёл строкой' do
      result = message('recognized_result', message: 'ИТОГО: 154.00')

      expect(described_class.call(result)).to eq('tesseract')
    end

    it 'считает источником yandex-vision, если пришёл ответ OCR-объектом' do
      result = message('recognized_result', message: { result: { textAnnotation: { fullText: 'ИТОГО' } } })

      expect(described_class.call(result)).to eq('yandex-vision')
    end
  end

  describe 'регистрация стоимости' do
    it 'считает источником check-ruler полный payload' do
      register = message('pay_register', file: '5775dae8f4b10.jpeg', price: 154.0)

      expect(described_class.call(register)).to eq('check-ruler')
    end

    it 'считает источником budget-control сокращённый payload после одобрения' do
      register = message('pay_register', full_path: 'attachment/2026-07-31/check.jpeg', price: 1500.0)

      expect(described_class.call(register)).to eq('budget-control')
    end
  end

  it 'не выдумывает источник для неизвестного действия' do
    expect(described_class.call(message('unknown_action'))).to be_nil
  end

  it 'разбирает сообщение со строковыми ключами' do
    expect(described_class.call('action' => 'recognize', 'payload' => {})).to eq('check-manager')
  end
end
