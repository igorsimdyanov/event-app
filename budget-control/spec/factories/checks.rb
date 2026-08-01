# frozen_string_literal: true

FactoryBot.define do
  factory :check do
    price { '250.00' }
    file { 'attachment/2026-07-31/check.png' }
    attachment_id { SecureRandom.uuid }
    approved { false }

    trait :approved do
      approved { true }
    end
  end
end
