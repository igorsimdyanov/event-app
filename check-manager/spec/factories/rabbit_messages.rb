# frozen_string_literal: true

FactoryBot.define do
  factory :rabbit_message do
    action { 'attachment_registered' }
    direction { RabbitMessage::INCOME_MESSAGE }
    routing_key { 'inbox.out' }
    success { true }
    data { { action: action, payload: { file: 'check.jpeg' } } }

    trait :outcome do
      direction { RabbitMessage::OUTCOME_MESSAGE }
    end

    trait :failed do
      success { false }
      error_message { 'Something went wrong' }
    end
  end
end
