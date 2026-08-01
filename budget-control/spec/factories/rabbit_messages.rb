# frozen_string_literal: true

FactoryBot.define do
  factory :rabbit_message do
    action { 'budget_check' }
    direction { RabbitMessage::INCOME_MESSAGE }
    routing_key { 'budget_control.in' }
    success { true }
    data { { action: action, payload: { price: '250.00' } } }

    trait :outcome do
      direction { RabbitMessage::OUTCOME_MESSAGE }
    end

    trait :failed do
      success { false }
      error_message { 'Something went wrong' }
    end
  end
end
