# frozen_string_literal: true

FactoryBot.define do
  factory :rabbit_message do
    action { 'pay_analyse' }
    direction { RabbitMessage::INCOME_MESSAGE }
    routing_key { 'check_manager.out' }
    success { true }
    data { { action: action, payload: { message: 'СУММА=250.00' } } }

    trait :outcome do
      direction { RabbitMessage::OUTCOME_MESSAGE }
    end

    trait :failed do
      success { false }
      error_message { 'Something went wrong' }
    end
  end
end
