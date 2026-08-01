# frozen_string_literal: true

RSpec.describe Check, type: :model do
  it 'является валидным с фабричными атрибутами' do
    expect(build(:check)).to be_valid
  end

  it 'сохраняет цену и идентификатор вложения' do
    attachment_id = SecureRandom.uuid
    check = create(:check, price: '199.99', attachment_id: attachment_id)

    expect(check.reload).to have_attributes(price: '199.99', attachment_id: attachment_id)
  end

  describe 'настройки Ransack' do
    it 'ограничивает атрибуты для поиска публичным списком' do
      expect(described_class.ransackable_attributes).to eq(Check::PUBLIC_FIELDS)
    end

    it 'перечисляет в публичном списке только существующие столбцы модели' do
      expect(Check::PUBLIC_FIELDS).to all(be_in(described_class.column_names))
    end

    it 'ограничивает ассоциации для поиска публичным списком' do
      expect(described_class.ransackable_associations).to eq(Check::RANSACK_ASSOCIATIONS)
    end
  end
end
