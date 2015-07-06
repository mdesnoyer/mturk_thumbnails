# encoding: UTF-8
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
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 15) do

  create_table "filter_stats", :force => true do |t|
    t.string  "worker_id"
    t.string  "stimset"
    t.float   "p_rand"
    t.integer "max_same_slot"
  end

  create_table "image_choices", :force => true do |t|
    t.string   "assignment_id"
    t.string   "image_one"
    t.string   "image_two"
    t.string   "image_three"
    t.string   "chosen_image"
    t.datetime "created_at",    :null => false
    t.datetime "updated_at",    :null => false
    t.string   "condition"
    t.integer  "trial"
    t.string   "worker_id"
    t.string   "stimset_id"
    t.integer  "reaction_time"
  end

  create_table "image_scores", :force => true do |t|
    t.string  "image"
    t.float   "valence"
    t.string  "stimset"
    t.integer "valid_keeps"
    t.integer "valid_returns"
  end

  create_table "jobs_completed", :force => true do |t|
    t.string "worker_id"
    t.string "stimset"
  end

  create_table "rejection_warnings", :force => true do |t|
    t.string   "worker_id"
    t.datetime "last_warning_time"
    t.integer  "last_warning_level"
  end

  create_table "trial_rejections", :force => true do |t|
    t.string  "worker_id"
    t.string  "stimset"
    t.string  "reason"
    t.integer "count"
  end

  create_table "user_rejections", :force => true do |t|
    t.string   "worker_id"
    t.string   "stimset"
    t.string   "reason"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "worker_info", :force => true do |t|
    t.string   "worker_id"
    t.string   "remote_ip"
    t.string   "x_forwarded_for"
    t.datetime "created_at",                   :null => false
    t.datetime "updated_at",                   :null => false
    t.string   "gender",          :limit => 1
    t.string   "age_group"
  end

end
