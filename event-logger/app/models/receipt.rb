class Receipt < ApplicationRecord
  include Ransackable

  has_many :events, -> { chronological }, dependent: :destroy, inverse_of: :receipt

  validates :attachment_id, presence: true, uniqueness: true

  PUBLIC_FIELDS = %w[
    id attachment_id file full_path price last_action events_count
    failed_events_count first_event_at last_event_at created_at updated_at
  ]
  RANSACK_ASSOCIATIONS = %w[events]

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
