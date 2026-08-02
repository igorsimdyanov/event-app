# frozen_string_literal: true

FactoryBot.define do
  factory :event do
    check
    attachment_id { check.attachment_id }
    action { 'pay_register' }
    routing_key { action }
    source { 'check-ruler' }
    occurred_at { Time.current }
    success { true }
    data { { action: action, payload: { attachment_id: attachment_id, price: '250.00' } } }

    trait :failed do
      success { false }
      error_message { 'Something went wrong' }
    end
  end
end
