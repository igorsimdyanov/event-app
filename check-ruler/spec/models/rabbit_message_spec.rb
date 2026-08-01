# frozen_string_literal: true

RSpec.describe RabbitMessage, type: :model do
  subject(:rabbit_message) { build(:rabbit_message) }

  it 'является валидным с фабричными атрибутами' do
    expect(rabbit_message).to be_valid
  end

  describe 'валидации' do
    it { is_expected.to validate_presence_of(:action) }

    it 'невалидно без action' do
      rabbit_message.action = nil
      expect(rabbit_message).not_to be_valid
    end
  end

  describe 'направление сообщения (enum direction)' do
    it { is_expected.to define_enum_for(:direction).with_values(income: 'income', outcome: 'outcome').backed_by_column_of_type(:string) }

    it 'знает о входящих и исходящих сообщениях' do
      expect(RabbitMessage::DIRECTIONS).to contain_exactly('income', 'outcome')
    end

    it 'по умолчанию сообщение входящее' do
      expect(create(:rabbit_message).direction).to eq('income')
    end
  end

  describe 'настройки Ransack' do
    it 'ограничивает атрибуты для поиска публичным списком' do
      expect(described_class.ransackable_attributes).to eq(RabbitMessage::PUBLIC_FIELDS)
    end

    it 'ограничивает ассоциации для поиска публичным списком' do
      expect(described_class.ransackable_associations).to eq(RabbitMessage::RANSACK_ASSOCIATIONS)
    end
  end
end
