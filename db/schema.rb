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

ActiveRecord::Schema[8.1].define(version: 2026_04_27_084507) do
  create_table "command_attempts", force: :cascade do |t|
    t.datetime "created_at"
    t.boolean "is_correct", default: false
    t.string "keyword_id"
    t.string "keyword_input"
    t.datetime "updated_at"
    t.integer "user_id", null: false
    t.integer "user_session_id", null: false
    t.index ["user_id"], name: "index_command_attempts_on_user_id"
    t.index ["user_session_id"], name: "index_command_attempts_on_user_session_id"
  end

  create_table "donations", force: :cascade do |t|
    t.boolean "completed", default: false
    t.datetime "created_at", null: false
    t.integer "seconds"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "user_session_id"
    t.index ["user_id"], name: "index_donations_on_user_id"
    t.index ["user_session_id"], name: "index_donations_on_user_session_id"
  end

  create_table "game_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "game_key", null: false
    t.integer "score", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "user_session_id"
    t.index ["game_key", "score"], name: "index_game_sessions_on_game_key_and_score"
    t.index ["user_id", "game_key"], name: "index_game_sessions_on_user_id_and_game_key"
    t.index ["user_id"], name: "index_game_sessions_on_user_id"
    t.index ["user_session_id"], name: "index_game_sessions_on_user_session_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "system_payloads", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key"
    t.string "kind"
    t.text "payload"
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_system_payloads_on_key", unique: true
  end

  create_table "unlockables", force: :cascade do |t|
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "kind", null: false
    t.text "payload"
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_unlockables_on_key", unique: true
  end

  create_table "user_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "duration_seconds"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_user_sessions_on_user_id"
  end

  create_table "user_unlocks", force: :cascade do |t|
    t.integer "unlockable_id", null: false
    t.integer "user_id", null: false
    t.index ["unlockable_id"], name: "index_user_unlocks_on_unlockable_id"
    t.index ["user_id"], name: "index_user_unlocks_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "code_verified", default: false
    t.boolean "consenso_promozionale", default: false
    t.datetime "consenso_promozionale_at"
    t.datetime "created_at", null: false
    t.string "email"
    t.boolean "email_verified", default: false
    t.datetime "first_seen_at"
    t.string "password_digest"
    t.integer "total_sessions_count", default: 0
    t.datetime "updated_at", null: false
    t.string "username"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "word_definitions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "definition"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "user_session_id"
    t.string "word"
    t.index ["user_id", "word"], name: "index_word_definitions_on_user_id_and_word", unique: true
    t.index ["user_id"], name: "index_word_definitions_on_user_id"
    t.index ["user_session_id"], name: "index_word_definitions_on_user_session_id"
  end

  add_foreign_key "command_attempts", "user_sessions"
  add_foreign_key "command_attempts", "users"
  add_foreign_key "donations", "user_sessions"
  add_foreign_key "donations", "users"
  add_foreign_key "game_sessions", "user_sessions"
  add_foreign_key "game_sessions", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "user_sessions", "users"
  add_foreign_key "user_unlocks", "unlockables"
  add_foreign_key "user_unlocks", "users"
  add_foreign_key "word_definitions", "user_sessions"
  add_foreign_key "word_definitions", "users"
end
