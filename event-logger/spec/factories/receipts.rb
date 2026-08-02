# frozen_string_literal: true

FactoryBot.define do
  factory :receipt do
    attachment_id { SecureRandom.uuid }
    file { '5775dae8f4b10.jpeg' }
    full_path { 'attachment/2026-07-31/5775dae8f4b10.jpeg' }
    last_action { 'attachment_registered' }
  end
end
