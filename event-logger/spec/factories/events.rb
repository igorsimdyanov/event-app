# frozen_string_literal: true

FactoryBot.define do
  factory :event do
    receipt
    attachment_id { receipt.attachment_id }
    action { 'pay_register' }
    routing_key { 'pay_register' }
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
