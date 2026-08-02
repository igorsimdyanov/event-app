# rubocop:disable Metrics/BlockLength
ActiveAdmin.register Event do
  menu priority: 3, label: proc { t('active_admin.events') }

  config.sort_order = 'occurred_at_desc'

  actions :index, :show

  filter :action, as: :select,
                  collection: proc { Event.distinct.pluck(:action).compact.sort }
  filter :source, as: :select,
                  collection: proc { Event.distinct.pluck(:source).compact.sort }
  filter :success
  filter :attachment_id_cont, as: :string, label: proc { I18n.t('active_admin.filters.correlation_id') }
  filter :occurred_at

  controller do
    def scoped_collection
      end_of_association_chain.includes(:receipt)
    end
  end

  index do
    column :occurred_at
    column :source
    column :action
    column :routing_key
    column :success do |event|
      status_tag event.success?, class: event.success? ? 'success' : 'error'
    end
    column :receipt do |event|
      if event.receipt
        link_to event.receipt.attachment_id, admin_receipt_path(event.receipt)
      else
        event.attachment_id
      end
    end
    column :error_message
    actions
  end

  show do
    attributes_table do
      row :receipt do |event|
        event.receipt && link_to(event.receipt.attachment_id, admin_receipt_path(event.receipt))
      end
      row :attachment_id
      row :action
      row :routing_key
      row :source
      row :occurred_at
      row :success do |event|
        status_tag event.success?, class: event.success? ? 'success' : 'error'
      end
      row :error_message
      row :created_at
      row :data do |event|
        div class: 'b-json__show', 'data-json': event.data.to_json
      end
      row :error_backtrace do |event|
        tag.pre do
          event.error_backtrace
        end
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
