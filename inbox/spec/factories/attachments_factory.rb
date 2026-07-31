# frozen_string_literal: true

FactoryBot.define do
  factory :attachment do
    file { Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/check001.jpeg'), 'image/jpeg') }
    sequence(:md5) { |n| Digest::MD5.hexdigest("attachment-#{n}") }

    trait :sent do
      sent { true }
    end
  end
end
