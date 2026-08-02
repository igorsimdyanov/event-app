class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    create_table(
      :events,
      id: :uuid,
      default: -> { 'gen_random_uuid()' },
      comment: 'События микросервисов, собранные из обменника services',
      force: :cascade
    ) do |t|
      t.references :receipt, type: :uuid, foreign_key: true, comment: 'Чек, к которому относится событие'
      t.uuid :attachment_id, comment: 'Correlation-id события из payload сообщения'
      t.string :action, null: false, comment: 'Тип/экшен сообщения'
      t.string :routing_key, comment: 'Фактический ключ маршрутизации доставки'
      t.string :source, comment: 'Микросервис — источник события'
      t.jsonb :data, comment: 'Сообщение целиком'
      t.datetime :occurred_at, comment: 'Время создания сообщения в микросервисе-источнике'
      t.boolean :success, null: false, default: true, comment: 'Сообщение обработалось?'
      t.string :error_message, comment: 'Сообщение об ошибке'
      t.text :error_backtrace, comment: 'Стектрейс ошибки'

      t.timestamps
    end

    add_index :events, %i[receipt_id occurred_at]
    add_index :events, :attachment_id
    add_index :events, :action
    add_index :events, :occurred_at
  end
end
