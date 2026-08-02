module Ransackable extend ActiveSupport::Concern
  class_methods do
    def ransackable_attributes(auth_object = nil)
      self::PUBLIC_FIELDS
    end

    def ransackable_associations(auth_object = nil)
      self::RANSACK_ASSOCIATIONS
    end
  end
end
