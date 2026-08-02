# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_02_110000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "checks", id: :uuid, default: -> { "gen_random_uuid()" }, comment: "Чеки — бизнес-транзакции, сгруппированные по correlation_id", force: :cascade do |t|
    t.uuid "attachment_id", null: false, comment: "Сквозной идентификатор бизнес-транзакции (ADR-0004)"
    t.datetime "created_at", null: false
    t.integer "events_count", default: 0, null: false, comment: "Количество зарегистрированных событий"
    t.integer "failed_events_count", default: 0, null: false, comment: "Количество событий с ошибкой"
    t.string "file", comment: "Имя файла вложения"
    t.datetime "first_event_at", comment: "Время первого события по чеку"
    t.string "full_path", comment: "Ключ (путь) файла вложения в S3"
    t.string "last_action", comment: "Действие последнего события по чеку"
    t.datetime "last_event_at", comment: "Время последнего события по чеку"
    t.string "price", comment: "Стоимость товаров и услуг из чека"
    t.datetime "updated_at", null: false
    t.index ["attachment_id"], name: "index_checks_on_attachment_id", unique: true
    t.index ["last_event_at"], name: "index_checks_on_last_event_at"
  end

  create_table "events", id: :uuid, default: -> { "gen_random_uuid()" }, comment: "События микросервисов, собранные из обменника services", force: :cascade do |t|
    t.string "action", null: false, comment: "Тип/экшен сообщения"
    t.uuid "attachment_id", comment: "Correlation-id события из payload сообщения"
    t.uuid "check_id", comment: "Чек, к которому относится событие"
    t.datetime "created_at", null: false
    t.jsonb "data", comment: "Сообщение целиком"
    t.text "error_backtrace", comment: "Стектрейс ошибки"
    t.string "error_message", comment: "Сообщение об ошибке"
    t.datetime "occurred_at", comment: "Время создания сообщения в микросервисе-источнике"
    t.string "routing_key", comment: "Фактический ключ маршрутизации доставки"
    t.string "source", comment: "Микросервис — источник события"
    t.boolean "success", default: true, null: false, comment: "Сообщение обработалось?"
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_events_on_action"
    t.index ["attachment_id"], name: "index_events_on_attachment_id"
    t.index ["check_id", "occurred_at"], name: "index_events_on_check_id_and_occurred_at"
    t.index ["check_id"], name: "index_events_on_check_id"
    t.index ["occurred_at"], name: "index_events_on_occurred_at"
  end

  add_foreign_key "events", "checks"
end
