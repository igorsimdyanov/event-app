class RabbitMessage < ApplicationRecord
  include Ransackable

  INCOME_MESSAGE = 'income'.freeze
  OUTCOME_MESSAGE = 'outcome'.freeze
  DIRECTIONS = [ INCOME_MESSAGE, OUTCOME_MESSAGE ].freeze

  enum :direction, DIRECTIONS.index_by(&:to_sym)

  validates :action, presence: true
  validates :direction, inclusion: { in: DIRECTIONS }

  PUBLIC_FIELDS = %w[id direction action routing_key success error_message created_at updated_at]
  RANSACK_ASSOCIATIONS = %w[id direction action routing_key success error_message created_at updated_at]

  # Названия направлений для панели администрирования
  def self.human_direction(direction)
    return if direction.blank?

    I18n.t(direction, scope: 'activerecord.attributes.rabbit_message.directions',
      default: direction.to_s)
  end

  def self.direction_options
    DIRECTIONS.map { |direction| [ human_direction(direction), direction ] }
  end

  def human_direction
    self.class.human_direction(direction)
  end
end
