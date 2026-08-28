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

ActiveRecord::Schema[8.1].define(version: 2026_08_27_190000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "access_requests", id: :serial, force: :cascade do |t|
    t.datetime "completed_at"
    t.integer "completed_by_id"
    t.datetime "created_at"
    t.string "current_state", default: "pending", null: false
    t.integer "current_worker_id"
    t.integer "help_desk_id"
    t.boolean "historical", default: false, null: false
    t.integer "hr_id"
    t.integer "manager_id"
    t.integer "position"
    t.string "request_action", null: false
    t.integer "request_id"
    t.integer "resource_id", null: false
    t.integer "resource_owner_id"
    t.datetime "updated_at"
    t.index ["current_worker_id"], name: "index_access_requests_on_current_worker_id"
    t.index ["request_id", "position"], name: "index_access_requests_on_request_id_and_position"
    t.index ["request_id"], name: "index_access_requests_on_request_id"
  end

  create_table "change_logs", id: :serial, force: :cascade do |t|
    t.string "attribute_name"
    t.string "changed_by"
    t.datetime "created_at"
    t.integer "item_id", null: false
    t.string "item_type", null: false
    t.text "new_value"
    t.text "old_value"
    t.integer "revision"
    t.index ["item_type", "item_id"], name: "index_change_logs_on_item_type_and_item_id"
  end

  create_table "companies", id: :serial, force: :cascade do |t|
    t.datetime "created_at"
    t.string "email_domain"
    t.string "name"
    t.datetime "updated_at"
  end

  create_table "departments", id: :serial, force: :cascade do |t|
    t.datetime "created_at"
    t.integer "location_id", null: false
    t.string "name", null: false
    t.datetime "updated_at"
    t.index ["location_id", "name"], name: "index_departments_on_location_id_and_name"
    t.index ["name"], name: "index_departments_on_name"
  end

  create_table "employment_types", id: :serial, force: :cascade do |t|
    t.datetime "created_at"
    t.string "name"
    t.datetime "updated_at"
    t.index ["name"], name: "index_employment_types_on_name"
  end

  create_table "jobs", id: :serial, force: :cascade do |t|
    t.datetime "created_at"
    t.string "current_state", default: "active", null: false
    t.integer "department_id", null: false
    t.string "lawson_cd"
    t.string "name", null: false
    t.integer "revision", default: 1, null: false
    t.datetime "updated_at"
    t.index ["department_id", "name"], name: "index_jobs_on_department_id_and_name"
    t.index ["name"], name: "index_jobs_on_name"
  end

  create_table "jobs_permissions", id: false, force: :cascade do |t|
    t.integer "job_id", null: false
    t.integer "permission_id", null: false
    t.index ["job_id", "permission_id"], name: "index_jobs_permissions_on_job_id_and_permission_id"
  end

  create_table "linked_accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.datetime "last_authenticated_at"
    t.string "provider", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["provider", "uid"], name: "index_linked_accounts_on_provider_and_uid", unique: true
    t.index ["user_id", "provider"], name: "index_linked_accounts_on_user_id_and_provider", unique: true
  end

  create_table "locations", id: :serial, force: :cascade do |t|
    t.datetime "created_at"
    t.string "name", null: false
    t.datetime "updated_at"
    t.index ["name"], name: "index_locations_on_name"
  end

  create_table "mailer_templates", id: :serial, force: :cascade do |t|
    t.text "body"
    t.datetime "created_at"
    t.text "description"
    t.string "format"
    t.string "handler"
    t.string "locale"
    t.boolean "partial", default: false
    t.string "path"
    t.datetime "updated_at"
    t.index ["path"], name: "index_mailer_templates_on_path"
  end

  create_table "notes", id: :serial, force: :cascade do |t|
    t.text "body"
    t.datetime "created_at"
    t.string "created_at_step"
    t.integer "notable_id"
    t.string "notable_type"
    t.datetime "updated_at"
    t.integer "user_id"
    t.index ["notable_type", "notable_id"], name: "index_notes_on_notable_type_and_notable_id"
  end

  create_table "permission_requests", id: :serial, force: :cascade do |t|
    t.integer "access_request_id", null: false
    t.boolean "approved_by_hr"
    t.datetime "approved_by_hr_at"
    t.boolean "approved_by_manager"
    t.datetime "approved_by_manager_at"
    t.boolean "approved_by_resource_owner"
    t.datetime "approved_by_resource_owner_at"
    t.datetime "created_at"
    t.boolean "permission_granted"
    t.integer "permission_id", null: false
    t.datetime "updated_at"
    t.index ["access_request_id"], name: "index_permission_requests_on_access_request_id"
  end

  create_table "permission_types", id: :serial, force: :cascade do |t|
    t.datetime "created_at"
    t.string "name", null: false
    t.integer "resource_group_id"
    t.datetime "updated_at"
    t.index ["name"], name: "index_permission_types_on_name"
    t.index ["resource_group_id", "name"], name: "index_permission_types_on_resource_group_id_and_name"
    t.index ["resource_group_id"], name: "index_permission_types_on_resource_group_id"
  end

  create_table "permissions", id: :serial, force: :cascade do |t|
    t.boolean "activated", default: true
    t.datetime "created_at"
    t.integer "permission_type_id", null: false
    t.integer "resource_id", null: false
    t.datetime "updated_at"
    t.index ["permission_type_id", "resource_id"], name: "index_permissions_on_permission_type_id_and_resource_id"
    t.index ["resource_id"], name: "index_permissions_on_resource_id"
  end

  create_table "permissions_users", id: false, force: :cascade do |t|
    t.integer "permission_id", null: false
    t.integer "user_id", null: false
    t.index ["permission_id", "user_id"], name: "index_permissions_users_on_permission_id_and_user_id"
    t.index ["user_id", "permission_id"], name: "index_permissions_users_on_user_id_and_permission_id"
  end

  create_table "preferences", id: :serial, force: :cascade do |t|
    t.datetime "created_at"
    t.integer "group_id"
    t.string "group_type"
    t.string "name", null: false
    t.integer "owner_id", null: false
    t.string "owner_type", null: false
    t.datetime "updated_at"
    t.string "value"
  end

  create_table "requests", id: :serial, force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at"
    t.integer "created_by_id", null: false
    t.string "current_state", default: "pending", null: false
    t.string "reason", default: "standard", null: false
    t.datetime "updated_at"
    t.integer "user_id", null: false
    t.index ["current_state"], name: "index_requests_on_current_state"
    t.index ["reason"], name: "index_requests_on_reason"
    t.index ["user_id"], name: "index_requests_on_user_id"
  end

  create_table "resource_groups", id: :serial, force: :cascade do |t|
    t.datetime "created_at"
    t.string "name", null: false
    t.datetime "updated_at"
    t.index ["name"], name: "index_resource_groups_on_name"
  end

  create_table "resources", id: :serial, force: :cascade do |t|
    t.datetime "created_at"
    t.string "current_state", default: "active", null: false
    t.string "name", null: false
    t.integer "resource_group_id"
    t.datetime "updated_at"
    t.index ["name"], name: "index_resources_on_name"
    t.index ["resource_group_id", "name"], name: "index_resources_on_resource_group_id_and_name"
    t.index ["resource_group_id"], name: "index_resources_on_resource_group_id"
  end

  create_table "resources_users", id: false, force: :cascade do |t|
    t.integer "resource_id", null: false
    t.integer "user_id", null: false
    t.index ["resource_id", "user_id"], name: "index_resources_users_on_resource_id_and_user_id"
    t.index ["user_id", "resource_id"], name: "index_resources_users_on_user_id_and_resource_id"
  end

  create_table "roles", id: :serial, force: :cascade do |t|
    t.string "name", null: false
    t.index ["name"], name: "index_roles_on_name"
  end

  create_table "roles_users", id: false, force: :cascade do |t|
    t.integer "role_id", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "role_id"], name: "index_roles_users_on_user_id_and_role_id"
  end

  create_table "user_sessions", id: :serial, force: :cascade do |t|
    t.datetime "created_at"
    t.text "data"
    t.string "session_id", null: false
    t.datetime "updated_at"
    t.index ["session_id"], name: "index_user_sessions_on_session_id"
    t.index ["updated_at"], name: "index_user_sessions_on_updated_at"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.datetime "activated_at"
    t.integer "company_id"
    t.integer "coworker_number"
    t.datetime "created_at"
    t.string "crypted_password"
    t.datetime "current_login_at"
    t.string "current_login_ip"
    t.string "current_state", default: "passive", null: false
    t.datetime "deleted_at"
    t.string "email", limit: 100, null: false
    t.integer "employment_type_id"
    t.date "end_date"
    t.integer "failed_login_count", default: 0, null: false
    t.string "first_name", limit: 40
    t.integer "job_id"
    t.datetime "last_login_at"
    t.string "last_login_ip"
    t.string "last_name", limit: 40
    t.datetime "last_request_at"
    t.integer "lft"
    t.string "login", limit: 40, default: ""
    t.integer "login_count", default: 0, null: false
    t.boolean "manager_flag", default: false, null: false
    t.integer "manager_id"
    t.string "nickname"
    t.boolean "nonhuman_flg", default: false
    t.string "password_salt"
    t.string "perishable_token", limit: 64
    t.string "persistence_token"
    t.integer "rgt"
    t.date "start_date"
    t.integer "submitted_by_id"
    t.integer "terminated_by_id"
    t.datetime "updated_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["employment_type_id"], name: "index_users_on_employment_type_id"
    t.index ["lft", "rgt"], name: "index_users_on_lft_and_rgt"
    t.index ["login"], name: "index_users_on_login"
    t.index ["manager_id"], name: "index_users_on_manager_id"
    t.index ["nonhuman_flg"], name: "index_users_on_nonhuman_flg"
    t.index ["rgt", "lft"], name: "index_users_on_rgt_and_lft"
  end
end
