class CreateReceipts < ActiveRecord::Migration[8.0]
  def change
    enable_extension 'pgcrypto'

    create_table(
      :receipts,
      id: :uuid,
      default: -> { 'gen_random_uuid()' },
      comment: 'Чеки — бизнес-транзакции, сгруппированные по correlation_id',
      force: :cascade
    ) do |t|
      t.uuid :attachment_id, null: false, comment: 'Сквозной идентификатор бизнес-транзакции (ADR-0004)'
      t.string :file, comment: 'Имя файла вложения'
      t.string :full_path, comment: 'Ключ (путь) файла вложения в S3'
      t.string :price, comment: 'Стоимость товаров и услуг из чека'
      t.string :last_action, comment: 'Действие последнего события по чеку'
      t.integer :events_count, null: false, default: 0, comment: 'Количество зарегистрированных событий'
      t.integer :failed_events_count, null: false, default: 0, comment: 'Количество событий с ошибкой'
      t.datetime :first_event_at, comment: 'Время первого события по чеку'
      t.datetime :last_event_at, comment: 'Время последнего события по чеку'

      t.timestamps
    end

    add_index :receipts, :attachment_id, unique: true
    add_index :receipts, :last_event_at
  end
end
