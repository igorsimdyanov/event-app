# frozen_string_literal: true

FactoryBot.define do
  factory :check do
    price { '250.00' }
    attachment_id { SecureRandom.uuid }
  end
end
