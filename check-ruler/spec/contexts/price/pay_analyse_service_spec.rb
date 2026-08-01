# frozen_string_literal: true

RSpec.describe Price::PayAnalyseService do
  let(:recognized_text) { 'СУММА=150.00' }
  let(:message) do
    {
      action: 'pay_analyse',
      payload: {
        file: 'check.png',
        full_path: 'attachment/2026-07-31/check.png',
        attachment_id: 'a1b2c3',
        created_at: 1_761_416_041,
        message: recognized_text
      }
    }
  end

  before { allow(RabbitMessages::Send).to receive(:call) }

  context 'когда сумма превышает порог бюджетного контроля (200)' do
    let(:recognized_text) { 'СУММА=250.00' }

    it 'отправляет чек на бюджетный контроль в очередь budget_control.in' do
      described_class.call(message)

      expect(RabbitMessages::Send).to have_received(:call) do |next_message, topic|
        expect(next_message[:action]).to eq('budget_check')
        expect(next_message.dig(:payload, :price)).to eq(250.0)
        expect(topic).to eq('budget_control.in')
      end
    end
  end

  context 'когда сумма в пределах порога' do
    let(:recognized_text) { 'СУММА=150.00' }

    it 'отправляет чек на регистрацию в очередь register.in' do
      described_class.call(message)

      expect(RabbitMessages::Send).to have_received(:call) do |next_message, topic|
        expect(next_message[:action]).to eq('pay_register')
        expect(next_message.dig(:payload, :price)).to eq(150.0)
        expect(topic).to eq('register.in')
      end
    end
  end

  context 'когда сумма ровно равна порогу (200)' do
    let(:recognized_text) { 'СУММА=200.00' }

    it 'отправляет на регистрацию — порог строго больше 200' do
      described_class.call(message)

      expect(RabbitMessages::Send).to have_received(:call)
        .with(hash_including(action: 'pay_register'), 'register.in')
    end
  end

  context 'когда текст распознан Yandex Vision (структура-хеш)' do
    let(:message) do
      {
        action: 'pay_analyse',
        payload: {
          message: { result: { textAnnotation: { fullText: 'СУММА=250.00' } } }
        }
      }
    end

    it 'извлекает распознанный текст из вложенной структуры Yandex Vision' do
      described_class.call(message)

      expect(RabbitMessages::Send).to have_received(:call) do |next_message, topic|
        expect(next_message.dig(:payload, :price)).to eq(250.0)
        expect(topic).to eq('budget_control.in')
      end
    end
  end

  context 'когда сумму в чеке не удалось распознать' do
    let(:recognized_text) { 'Чек без числовой суммы' }

    it 'отправляет чек на бюджетный контроль для ручной проверки' do
      described_class.call(message)

      expect(RabbitMessages::Send).to have_received(:call) do |next_message, topic|
        expect(next_message[:action]).to eq('budget_check')
        expect(next_message.dig(:payload, :price)).to be_nil
        expect(topic).to eq('budget_control.in')
      end
    end
  end
end
