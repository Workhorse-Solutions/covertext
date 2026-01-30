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

ActiveRecord::Schema[8.1].define(version: 2026_01_30_090000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "agencies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "live_enabled", default: false, null: false
    t.string "name", null: false
    t.string "plan_name"
    t.jsonb "settings", default: {}
    t.string "sms_phone_number", null: false
    t.string "stripe_customer_id"
    t.string "stripe_subscription_id"
    t.string "subscription_status"
    t.datetime "updated_at", null: false
    t.index ["sms_phone_number"], name: "index_agencies_on_sms_phone_number", unique: true
    t.index ["stripe_customer_id"], name: "index_agencies_on_stripe_customer_id", unique: true
    t.index ["stripe_subscription_id"], name: "index_agencies_on_stripe_subscription_id", unique: true
  end

  create_table "audit_events", force: :cascade do |t|
    t.bigint "agency_id", null: false
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.jsonb "metadata", default: {}
    t.bigint "request_id"
    t.datetime "updated_at", null: false
    t.index ["agency_id"], name: "index_audit_events_on_agency_id"
    t.index ["request_id"], name: "index_audit_events_on_request_id"
  end

  create_table "contacts", force: :cascade do |t|
    t.bigint "agency_id", null: false
    t.datetime "created_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "mobile_phone_e164", null: false
    t.datetime "updated_at", null: false
    t.index ["agency_id", "mobile_phone_e164"], name: "index_contacts_on_agency_id_and_mobile_phone_e164", unique: true
    t.index ["agency_id"], name: "index_contacts_on_agency_id"
  end

  create_table "conversation_sessions", force: :cascade do |t|
    t.bigint "agency_id", null: false
    t.jsonb "context", default: {}
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "from_phone_e164", null: false
    t.datetime "last_activity_at"
    t.string "state", null: false
    t.datetime "updated_at", null: false
    t.index ["agency_id", "from_phone_e164"], name: "index_conversation_sessions_on_agency_id_and_from_phone_e164", unique: true
    t.index ["agency_id"], name: "index_conversation_sessions_on_agency_id"
  end

  create_table "deliveries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_status_at"
    t.string "method", null: false
    t.string "provider_message_id"
    t.bigint "request_id", null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["provider_message_id"], name: "index_deliveries_on_provider_message_id"
    t.index ["request_id"], name: "index_deliveries_on_request_id"
  end

  create_table "documents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "kind", default: "auto_id_card", null: false
    t.bigint "policy_id", null: false
    t.datetime "updated_at", null: false
    t.index ["policy_id"], name: "index_documents_on_policy_id"
  end

  create_table "message_logs", force: :cascade do |t|
    t.bigint "agency_id", null: false
    t.text "body"
    t.datetime "created_at", null: false
    t.string "direction", null: false
    t.string "from_phone"
    t.integer "media_count", default: 0
    t.string "provider_message_id"
    t.bigint "request_id"
    t.string "to_phone"
    t.datetime "updated_at", null: false
    t.index ["agency_id"], name: "index_message_logs_on_agency_id"
    t.index ["provider_message_id"], name: "index_message_logs_on_provider_message_id"
    t.index ["request_id"], name: "index_message_logs_on_request_id"
  end

  create_table "policies", force: :cascade do |t|
    t.bigint "contact_id", null: false
    t.datetime "created_at", null: false
    t.date "expires_on", null: false
    t.string "label", null: false
    t.string "policy_type", null: false
    t.datetime "updated_at", null: false
    t.index ["contact_id"], name: "index_policies_on_contact_id"
  end

  create_table "requests", force: :cascade do |t|
    t.bigint "agency_id", null: false
    t.bigint "contact_id"
    t.datetime "created_at", null: false
    t.string "failure_reason"
    t.datetime "fulfilled_at"
    t.text "inbound_body"
    t.string "request_type", null: false
    t.string "selected_ref"
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["agency_id"], name: "index_requests_on_agency_id"
    t.index ["contact_id"], name: "index_requests_on_contact_id"
  end

  create_table "sms_opt_outs", force: :cascade do |t|
    t.bigint "agency_id", null: false
    t.datetime "created_at", null: false
    t.datetime "last_block_notice_at"
    t.datetime "opted_out_at", null: false
    t.string "phone_e164", null: false
    t.datetime "updated_at", null: false
    t.index ["agency_id", "phone_e164"], name: "index_sms_opt_outs_on_agency_id_and_phone_e164", unique: true
    t.index ["agency_id"], name: "index_sms_opt_outs_on_agency_id"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "agency_id", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "password_digest", null: false
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token_digest"
    t.string "role", default: "admin"
    t.datetime "updated_at", null: false
    t.index ["agency_id"], name: "index_users_on_agency_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token_digest"], name: "index_users_on_reset_password_token_digest", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "audit_events", "agencies"
  add_foreign_key "audit_events", "requests"
  add_foreign_key "contacts", "agencies"
  add_foreign_key "conversation_sessions", "agencies"
  add_foreign_key "deliveries", "requests"
  add_foreign_key "documents", "policies"
  add_foreign_key "message_logs", "agencies"
  add_foreign_key "message_logs", "requests"
  add_foreign_key "policies", "contacts"
  add_foreign_key "requests", "agencies"
  add_foreign_key "requests", "contacts"
  add_foreign_key "sms_opt_outs", "agencies"
  add_foreign_key "users", "agencies"
end
