# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2018_08_16_165202) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "hstore"
  enable_extension "plpgsql"

  create_table "admin_configurations", force: :cascade do |t|
    t.string "config_type"
    t.string "value_type"
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "configuration_options", force: :cascade do |t|
    t.bigserial "admin_configuration_id", null: false
    t.string "name"
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "projects", force: :cascade do |t|
    t.bigserial "user_id", null: false
    t.string "namespace"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "user_role"
  end

  create_table "reference_analyses", force: :cascade do |t|
    t.string "firecloud_project"
    t.string "firecloud_workspace"
    t.string "analysis_wdl"
    t.string "benchmark_wdl"
    t.string "orchestration_wdl"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "reference_analysis_data", force: :cascade do |t|
    t.bigserial "reference_analysis_id", null: false
    t.string "parameter_name"
    t.string "parameter_value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "data_type"
    t.string "call_name"
  end

  create_table "reference_analysis_options", force: :cascade do |t|
    t.bigserial "reference_analysis_id", null: false
    t.string "name"
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "user_analyses", force: :cascade do |t|
    t.bigserial "user_workspace_id", null: false
    t.bigserial "user_id", null: false
    t.string "namespace"
    t.string "name"
    t.integer "snapshot"
    t.text "wdl_contents"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "user_workspaces", force: :cascade do |t|
    t.string "name"
    t.bigserial "project_id", null: false
    t.bigserial "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigserial "reference_analysis_id", null: false
    t.string "bucket_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.string "uid", default: "", null: false
    t.string "provider", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "full_name"
    t.hstore "access_token"
    t.string "encrypted_refresh_token"
    t.string "encrypted_refresh_token_iv"
    t.boolean "admin", default: false
    t.boolean "registered_for_firecloud", default: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

end
