# frozen_string_literal: true

RSpec.describe Event, type: :model do
  it 'является валидным с фабричными атрибутами' do
    expect(build(:event)).to be_valid
  end

  it 'требует действие' do
    expect(build(:event, action: nil)).not_to be_valid
  end

  it 'допускает событие без чека — например, сообщение без correlation-id' do
    expect(build(:event, check: nil, attachment_id: nil)).to be_valid
  end

  it 'ведёт счётчик событий чека' do
    check = create(:check)

    expect { create(:event, check: check) }.to change { check.reload.events_count }.by(1)
  end

  describe '.chronological' do
    it 'упорядочивает события по времени их возникновения в микросервисах' do
      check = create(:check)
      late = create(:event, check: check, occurred_at: Time.zone.at(200))
      early = create(:event, check: check, occurred_at: Time.zone.at(100))

      expect(described_class.chronological.to_a).to eq([ early, late ])
    end
  end

  describe '.failed' do
    it 'отбирает только неуспешные события' do
      create(:event)
      failed = create(:event, :failed)

      expect(described_class.failed.to_a).to eq([ failed ])
    end
  end

  describe '#payload' do
    it 'возвращает полезную нагрузку сообщения' do
      event = build(:event, data: { 'action' => 'pay_register', 'payload' => { 'price' => '250.00' } })

      expect(event.payload).to eq('price' => '250.00')
    end

    it 'возвращает пустую нагрузку, если сообщение не сохранено' do
      expect(build(:event, data: nil).payload).to eq({})
    end
  end

  describe 'настройки Ransack' do
    it 'ограничивает атрибуты для поиска публичным списком' do
      expect(described_class.ransackable_attributes).to eq(Event::PUBLIC_FIELDS)
    end

    it 'перечисляет в публичном списке только столбцы и ransacker-ы модели' do
      expect(Event::PUBLIC_FIELDS)
        .to all(be_in(described_class.column_names + described_class._ransackers.keys))
    end

    it 'ищет событие по части correlation-id' do
      event = create(:event)

      expect(described_class.ransack(attachment_id_text_cont: event.attachment_id.first(8)).result)
        .to eq([ event ])
    end

    it 'ограничивает ассоциации для поиска публичным списком' do
      expect(described_class.ransackable_associations).to eq(Event::RANSACK_ASSOCIATIONS)
    end
  end
end
