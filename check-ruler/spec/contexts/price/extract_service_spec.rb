# frozen_string_literal: true

RSpec.describe Price::ExtractService do
  describe '.call' do
    it 'извлекает сумму по метке СУММА' do
      expect(described_class.call('СУММА=250.00')).to eq(250.0)
    end

    it 'извлекает сумму по метке ИТОГ' do
      expect(described_class.call('ИТОГ=100.50')).to eq(100.5)
    end

    it 'извлекает сумму по метке НАЛИЧНЫМИ' do
      expect(described_class.call('НАЛИЧНЫМИ=75')).to eq(75.0)
    end

    it 'извлекает число после знака = при отсутствии меток' do
      expect(described_class.call('Всего к оплате =300')).to eq(300.0)
    end

    it 'допускает пробелы между меткой и знаком равенства' do
      expect(described_class.call('СУММА  =42.5')).to eq(42.5)
    end

    it 'не распознаёт сумму, если между знаком равенства и числом есть пробел' do
      expect(described_class.call('СУММА= 42.5')).to be_nil
    end

    it 'отдаёт приоритет метке СУММА перед прочими совпадениями' do
      expect(described_class.call("ИТОГ=100\nНАЛИЧНЫМИ=180\nСУММА=250")).to eq(250.0)
    end

    it 'возвращает nil, если сумма в тексте не найдена' do
      expect(described_class.call('Чек без числовых сумм')).to be_nil
    end
  end
end
