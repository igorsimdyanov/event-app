# rubocop:disable Metrics/BlockLength
ActiveAdmin.register RabbitMessage do
  menu priority: 5, label: proc { t('active_admin.rabbit_messages') }

  config.sort_order = 'created_at_desc'

  actions :index, :show

  filter :action, as: :select,
                  collection: proc { RabbitMessage.select(:action).distinct.pluck(:action).sort }
  filter :success
  filter :direction, as: :select, collection: proc { RabbitMessage.direction_options }

  controller do
    def scoped_collection
      end_of_association_chain.select(
        :id,
        :action,
        :direction,
        :success,
        :routing_key,
        :error_message,
        :created_at,
        :updated_at
      )
    end

    def find_resource
      scoped_collection.select(:data, :error_backtrace).find(params[:id])
    end
  end

  index do
    column :direction do |message|
      message.human_direction
    end
    column :action
    column :routing_key
    column :success
    column :error_message
    column :created_at
    column :updated_at
    actions
  end

  show do
    attributes_table do
      row :direction do |message|
        message.human_direction
      end
      row :action
      row :routing_key
      row :success
      row :error_message
      row :created_at
      row :updated_at
      row :data do |message|
        div class: 'b-json__show', 'data-json': message.data.to_json
      end
      row :error_backtrace do |message|
        tag.pre do
          message.error_backtrace
        end
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
