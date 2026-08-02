# frozen_string_literal: true

RSpec.describe Check, type: :model do
  it 'является валидным с фабричными атрибутами' do
    expect(build(:check)).to be_valid
  end

  it 'требует correlation-id' do
    expect(build(:check, attachment_id: nil)).not_to be_valid
  end

  it 'не допускает двух чеков с одним correlation-id' do
    attachment_id = SecureRandom.uuid
    create(:check, attachment_id: attachment_id)

    expect(build(:check, attachment_id: attachment_id)).not_to be_valid
  end

  describe '.for_correlation' do
    it 'создаёт чек при первом событии' do
      expect { described_class.for_correlation(SecureRandom.uuid) }.to change(described_class, :count).by(1)
    end

    it 'возвращает существующий чек при повторном обращении' do
      check = create(:check)

      expect(described_class.for_correlation(check.attachment_id)).to eq(check)
    end

    it 'не создаёт дубль для уже известного correlation-id' do
      check = create(:check)

      expect { described_class.for_correlation(check.attachment_id) }.not_to change(described_class, :count)
    end

    context 'когда параллельный воркер успел создать чек между SELECT и INSERT' do
      let!(:concurrent) { create(:check) }

      before do
        # Первый поиск ещё не видит чужой записи, INSERT упирается в уникальный
        # индекс, повторный поиск уже находит созданный чек
        lookups = 0
        allow(described_class).to receive(:find_by).and_wrap_original do |original, *args|
          lookups += 1
          lookups == 1 ? nil : original.call(*args)
        end
        allow(described_class).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique, 'duplicate key')
      end

      it 'возвращает чек, созданный параллельным воркером' do
        expect(described_class.for_correlation(concurrent.attachment_id)).to eq(concurrent)
      end

      it 'не поднимает ошибку уникальности наружу' do
        expect { described_class.for_correlation(concurrent.attachment_id) }.not_to raise_error
      end
    end
  end

  describe '#failed?' do
    it 'сообщает об ошибках, если по чеку есть неуспешные события' do
      expect(build(:check, failed_events_count: 1)).to be_failed
    end

    it 'не сообщает об ошибках, если все события успешны' do
      expect(build(:check, failed_events_count: 0)).not_to be_failed
    end
  end

  describe '#duration' do
    it 'считает длительность обработки чека' do
      check = build(:check, first_event_at: Time.zone.at(100), last_event_at: Time.zone.at(160))

      expect(check.duration).to eq(60)
    end

    it 'не считает длительность, пока событий недостаточно' do
      expect(build(:check, first_event_at: nil, last_event_at: nil).duration).to be_nil
    end
  end

  describe 'настройки Ransack' do
    it 'ограничивает атрибуты для поиска публичным списком' do
      expect(described_class.ransackable_attributes).to eq(Check::PUBLIC_FIELDS)
    end

    it 'перечисляет в публичном списке только столбцы и ransacker-ы модели' do
      expect(Check::PUBLIC_FIELDS)
        .to all(be_in(described_class.column_names + described_class._ransackers.keys))
    end

    it 'ищет чек по части correlation-id' do
      check = create(:check)

      expect(described_class.ransack(attachment_id_text_cont: check.attachment_id.first(8)).result)
        .to eq([ check ])
    end

    it 'ограничивает ассоциации для поиска публичным списком' do
      expect(described_class.ransackable_associations).to eq(Check::RANSACK_ASSOCIATIONS)
    end
  end
end
