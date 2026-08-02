# frozen_string_literal: true

RSpec.describe Receipt, type: :model do
  it 'является валидным с фабричными атрибутами' do
    expect(build(:receipt)).to be_valid
  end

  it 'требует correlation-id' do
    expect(build(:receipt, attachment_id: nil)).not_to be_valid
  end

  it 'не допускает двух чеков с одним correlation-id' do
    attachment_id = SecureRandom.uuid
    create(:receipt, attachment_id: attachment_id)

    expect(build(:receipt, attachment_id: attachment_id)).not_to be_valid
  end

  describe '.for_correlation' do
    it 'создаёт чек при первом событии' do
      expect { described_class.for_correlation(SecureRandom.uuid) }.to change(described_class, :count).by(1)
    end

    it 'возвращает существующий чек при повторном обращении' do
      receipt = create(:receipt)

      expect(described_class.for_correlation(receipt.attachment_id)).to eq(receipt)
    end

    it 'не создаёт дубль для уже известного correlation-id' do
      receipt = create(:receipt)

      expect { described_class.for_correlation(receipt.attachment_id) }.not_to change(described_class, :count)
    end
  end

  describe '#failed?' do
    it 'сообщает об ошибках, если по чеку есть неуспешные события' do
      expect(build(:receipt, failed_events_count: 1)).to be_failed
    end

    it 'не сообщает об ошибках, если все события успешны' do
      expect(build(:receipt, failed_events_count: 0)).not_to be_failed
    end
  end

  describe '#duration' do
    it 'считает длительность обработки чека' do
      receipt = build(:receipt, first_event_at: Time.zone.at(100), last_event_at: Time.zone.at(160))

      expect(receipt.duration).to eq(60)
    end

    it 'не считает длительность, пока событий недостаточно' do
      expect(build(:receipt, first_event_at: nil, last_event_at: nil).duration).to be_nil
    end
  end

  describe 'настройки Ransack' do
    it 'ограничивает атрибуты для поиска публичным списком' do
      expect(described_class.ransackable_attributes).to eq(Receipt::PUBLIC_FIELDS)
    end

    it 'перечисляет в публичном списке только существующие столбцы модели' do
      expect(Receipt::PUBLIC_FIELDS).to all(be_in(described_class.column_names))
    end

    it 'ограничивает ассоциации для поиска публичным списком' do
      expect(described_class.ransackable_associations).to eq(Receipt::RANSACK_ASSOCIATIONS)
    end
  end
end
