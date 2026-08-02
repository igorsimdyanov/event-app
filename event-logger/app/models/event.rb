class Event < ApplicationRecord
  include Ransackable

  belongs_to :receipt, optional: true, counter_cache: :events_count, inverse_of: :events

  validates :action, presence: true

  PUBLIC_FIELDS = %w[
    id attachment_id action routing_key source success error_message
    occurred_at created_at updated_at
  ]
  RANSACK_ASSOCIATIONS = %w[receipt]

  scope :chronological, -> { order(:occurred_at, :created_at) }
  scope :failed, -> { where(success: false) }

  def payload
    data&.dig('payload') || {}
  end
end
