# rubocop:disable Metrics/BlockLength
ActiveAdmin.register Receipt do
  menu priority: 2, label: proc { t('active_admin.receipts') }

  config.sort_order = 'last_event_at_desc'

  actions :index, :show

  filter :attachment_id_cont, as: :string, label: proc { I18n.t('active_admin.filters.correlation_id') }
  filter :last_action, as: :select,
                       collection: proc { Receipt.distinct.pluck(:last_action).compact.sort }
  filter :file_cont, as: :string, label: proc { I18n.t('activerecord.attributes.receipt.file') }
  filter :last_event_at

  index do
    column :attachment_id do |receipt|
      link_to receipt.attachment_id, admin_receipt_path(receipt)
    end
    column :file
    column :price
    column :last_action do |receipt|
      status_tag receipt.last_action, class: receipt.failed? ? 'error' : 'success'
    end
    column :events_count
    column :first_event_at
    column :last_event_at
    actions
  end

  show title: proc { |receipt| "#{I18n.t('active_admin.resources.receipt.one')} #{receipt.attachment_id}" } do
    attributes_table do
      row :attachment_id
      row :file
      row :full_path
      row :price
      row :last_action do |receipt|
        status_tag receipt.last_action, class: receipt.failed? ? 'error' : 'success'
      end
      row :events_count
      row :failed_events_count
      row :first_event_at
      row :last_event_at
      row :duration do |receipt|
        receipt.duration && "#{number_with_precision(receipt.duration, precision: 1)} c"
      end
    end

    events = resource.events.chronological.to_a
    timeline = Events::TimelineService.call(events)

    panel t('active_admin.event_timeline') do
      table_for events do
        column t('active_admin.timeline.step') do |event|
          timeline.position_of(event)
        end
        column Event.human_attribute_name(:occurred_at), :occurred_at
        column t('active_admin.timeline.delay') do |event|
          timeline.delay_of(event) && "+#{number_with_precision(timeline.delay_of(event), precision: 1)} c"
        end
        column Event.human_attribute_name(:source), :source
        column Event.human_attribute_name(:action), :action
        column Event.human_attribute_name(:routing_key), :routing_key
        column Event.human_attribute_name(:success) do |event|
          status_tag event.success?, class: event.success? ? 'success' : 'error'
        end
        column Event.human_attribute_name(:error_message), :error_message
        column Event.human_attribute_name(:data) do |event|
          div class: 'b-json__show', 'data-json': event.data.to_json
        end
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
