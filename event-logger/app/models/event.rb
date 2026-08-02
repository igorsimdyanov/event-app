class Event < ApplicationRecord
  include Ransackable

  belongs_to :check, optional: true, counter_cache: :events_count, inverse_of: :events

  validates :action, presence: true

  PUBLIC_FIELDS = %w[
    id attachment_id attachment_id_text action routing_key source success error_message
    occurred_at created_at updated_at
  ]
  RANSACK_ASSOCIATIONS = %w[check]

  # Поиск по части correlation-id: uuid-колонку нельзя сравнивать через LIKE
  ransacker :attachment_id_text do
    Arel.sql("#{table_name}.attachment_id::text")
  end

  scope :chronological, -> { order(:occurred_at, :created_at) }
  scope :failed, -> { where(success: false) }

  def payload
    data&.dig('payload') || {}
  end
end
