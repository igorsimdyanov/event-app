# frozen_string_literal: true

module Callable
  extend ActiveSupport::Concern

  class_methods do
    def call(...)
      new(...).call
    end
  end
end
