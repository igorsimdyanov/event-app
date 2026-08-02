class Check < ApplicationRecord
  include Ransackable

  has_many :events, -> { chronological }, dependent: :destroy, inverse_of: :check

  validates :attachment_id, presence: true, uniqueness: true

  PUBLIC_FIELDS = %w[
    id attachment_id attachment_id_text file full_path price last_action events_count
    failed_events_count first_event_at last_event_at created_at updated_at
  ]
  RANSACK_ASSOCIATIONS = %w[events]

  # Поиск по части correlation-id: uuid-колонку нельзя сравнивать через LIKE
  ransacker :attachment_id_text do
    Arel.sql("#{table_name}.attachment_id::text")
  end

  scope :recent, -> { order(last_event_at: :desc) }

  # Возвращает чек по correlation-id, создавая его при первом событии.
  # Вложенная транзакция изолирует гонку параллельных воркеров.
  def self.for_correlation(attachment_id)
    find_by(attachment_id: attachment_id) ||
      transaction(requires_new: true) { create!(attachment_id: attachment_id) }
  rescue ActiveRecord::RecordNotUnique
    find_by!(attachment_id: attachment_id)
  end

  def failed?
    failed_events_count.positive?
  end

  def duration
    return unless first_event_at && last_event_at

    last_event_at - first_event_at
  end
end
