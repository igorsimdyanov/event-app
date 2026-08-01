class Check < ApplicationRecord
  include Ransackable

  PUBLIC_FIELDS = %w[id price attachment_id created_at updated_at]
  RANSACK_ASSOCIATIONS = %w[id price attachment_id created_at updated_at]
end
