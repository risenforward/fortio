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
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20180605104154) do

  create_table "accounts", force: :cascade do |t|
    t.integer  "member_id",   limit: 4,                                          null: false
    t.string   "currency_id", limit: 10,                                         null: false
    t.decimal  "balance",                precision: 32, scale: 16, default: 0.0, null: false
    t.decimal  "locked",                 precision: 32, scale: 16, default: 0.0, null: false
    t.datetime "created_at",                                                     null: false
    t.datetime "updated_at",                                                     null: false
  end

  add_index "accounts", ["currency_id", "member_id"], name: "index_accounts_on_currency_id_and_member_id", unique: true, using: :btree
  add_index "accounts", ["member_id"], name: "index_accounts_on_member_id", using: :btree

  create_table "audit_logs", force: :cascade do |t|
    t.string   "type",           limit: 30, null: false
    t.integer  "operator_id",    limit: 4
    t.integer  "auditable_id",   limit: 4,  null: false
    t.string   "auditable_type", limit: 30, null: false
    t.string   "source_state",   limit: 30
    t.string   "target_state",   limit: 30, null: false
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
  end

  add_index "audit_logs", ["auditable_id", "auditable_type"], name: "index_audit_logs_on_auditable_id_and_auditable_type", using: :btree
  add_index "audit_logs", ["operator_id"], name: "index_audit_logs_on_operator_id", using: :btree

  create_table "authentications", force: :cascade do |t|
    t.string   "provider",   limit: 30,   null: false
    t.string   "uid",        limit: 255,  null: false
    t.string   "token",      limit: 1024
    t.integer  "member_id",  limit: 4,    null: false
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  add_index "authentications", ["member_id"], name: "index_authentications_on_member_id", using: :btree
  add_index "authentications", ["provider", "member_id", "uid"], name: "index_authentications_on_provider_and_member_id_and_uid", unique: true, using: :btree
  add_index "authentications", ["provider", "member_id"], name: "index_authentications_on_provider_and_member_id", unique: true, using: :btree
  add_index "authentications", ["provider", "uid"], name: "index_authentications_on_provider_and_uid", unique: true, using: :btree

  create_table "currencies", force: :cascade do |t|
    t.string   "symbol",               limit: 1,                                               null: false
    t.string   "type",                 limit: 30,                             default: "coin", null: false
    t.decimal  "deposit_fee",                       precision: 32, scale: 16, default: 0.0,    null: false
    t.decimal  "quick_withdraw_limit",              precision: 32, scale: 16, default: 0.0,    null: false
    t.decimal  "withdraw_fee",                      precision: 32, scale: 16, default: 0.0,    null: false
    t.string   "options",              limit: 1000,                           default: "{}",   null: false
    t.boolean  "enabled",                                                     default: true,   null: false
    t.integer  "base_factor",          limit: 8,                              default: 1,      null: false
    t.integer  "precision",            limit: 1,                              default: 8,      null: false
    t.datetime "created_at",                                                                   null: false
    t.datetime "updated_at",                                                                   null: false
  end

  add_index "currencies", ["enabled"], name: "index_currencies_on_enabled", using: :btree

  create_table "deposits", force: :cascade do |t|
    t.integer  "member_id",     limit: 4,                                         null: false
    t.string   "currency_id",   limit: 10,                                        null: false
    t.decimal  "amount",                    precision: 32, scale: 16,             null: false
    t.decimal  "fee",                       precision: 32, scale: 16,             null: false
    t.string   "address",       limit: 64
    t.string   "txid",          limit: 128
    t.integer  "txout",         limit: 4
    t.string   "aasm_state",    limit: 30,                                        null: false
    t.integer  "confirmations", limit: 4,                             default: 0, null: false
    t.string   "type",          limit: 30,                                        null: false
    t.string   "tid",           limit: 64,                                        null: false
    t.datetime "created_at",                                                      null: false
    t.datetime "updated_at",                                                      null: false
    t.datetime "completed_at"
  end

  add_index "deposits", ["aasm_state", "member_id", "currency_id"], name: "index_deposits_on_aasm_state_and_member_id_and_currency_id", using: :btree
  add_index "deposits", ["currency_id", "txid", "txout"], name: "index_deposits_on_currency_id_and_txid_and_txout", unique: true, using: :btree
  add_index "deposits", ["currency_id"], name: "index_deposits_on_currency_id", using: :btree
  add_index "deposits", ["member_id", "txid"], name: "index_deposits_on_member_id_and_txid", using: :btree
  add_index "deposits", ["tid"], name: "index_deposits_on_tid", using: :btree
  add_index "deposits", ["type"], name: "index_deposits_on_type", using: :btree

  create_table "markets", force: :cascade do |t|
    t.string   "ask_unit",      limit: 5,                                          null: false
    t.string   "bid_unit",      limit: 5,                                          null: false
    t.decimal  "ask_fee",                 precision: 17, scale: 16, default: 0.0,  null: false
    t.decimal  "bid_fee",                 precision: 17, scale: 16, default: 0.0,  null: false
    t.integer  "ask_precision", limit: 1,                           default: 8,    null: false
    t.integer  "bid_precision", limit: 1,                           default: 8,    null: false
    t.integer  "position",      limit: 4,                           default: 0,    null: false
    t.boolean  "enabled",                                           default: true, null: false
    t.datetime "created_at",                                                       null: false
    t.datetime "updated_at",                                                       null: false
  end

  add_index "markets", ["ask_unit", "bid_unit"], name: "index_markets_on_ask_unit_and_bid_unit", unique: true, using: :btree
  add_index "markets", ["ask_unit"], name: "index_markets_on_ask_unit", using: :btree
  add_index "markets", ["bid_unit"], name: "index_markets_on_bid_unit", using: :btree
  add_index "markets", ["enabled"], name: "index_markets_on_enabled", using: :btree
  add_index "markets", ["position"], name: "index_markets_on_position", using: :btree

  create_table "members", force: :cascade do |t|
    t.integer  "level",        limit: 1,   default: 0,     null: false
    t.string   "sn",           limit: 12,                  null: false
    t.string   "email",        limit: 255,                 null: false
    t.boolean  "disabled",                 default: false, null: false
    t.boolean  "api_disabled",             default: false, null: false
    t.datetime "created_at",                               null: false
    t.datetime "updated_at",                               null: false
  end

  add_index "members", ["disabled"], name: "index_members_on_disabled", using: :btree
  add_index "members", ["email"], name: "index_members_on_email", unique: true, using: :btree
  add_index "members", ["sn"], name: "index_members_on_sn", unique: true, using: :btree

  create_table "orders", force: :cascade do |t|
    t.string   "bid",            limit: 10,                                         null: false
    t.string   "ask",            limit: 10,                                         null: false
    t.string   "market_id",      limit: 10,                                         null: false
    t.decimal  "price",                     precision: 32, scale: 16
    t.decimal  "volume",                    precision: 32, scale: 16,               null: false
    t.decimal  "origin_volume",             precision: 32, scale: 16,               null: false
    t.decimal  "fee",                       precision: 32, scale: 16, default: 0.0, null: false
    t.integer  "state",          limit: 4,                                          null: false
    t.string   "type",           limit: 8,                                          null: false
    t.integer  "member_id",      limit: 4,                                          null: false
    t.string   "ord_type",       limit: 30,                                         null: false
    t.decimal  "locked",                    precision: 32, scale: 16, default: 0.0, null: false
    t.decimal  "origin_locked",             precision: 32, scale: 16, default: 0.0, null: false
    t.decimal  "funds_received",            precision: 32, scale: 16, default: 0.0
    t.integer  "trades_count",   limit: 4,                            default: 0,   null: false
    t.datetime "created_at",                                                        null: false
    t.datetime "updated_at",                                                        null: false
  end

  add_index "orders", ["member_id"], name: "index_orders_on_member_id", using: :btree
  add_index "orders", ["state"], name: "index_orders_on_state", using: :btree
  add_index "orders", ["type", "market_id"], name: "index_orders_on_type_and_market_id", using: :btree
  add_index "orders", ["type", "member_id"], name: "index_orders_on_type_and_member_id", using: :btree
  add_index "orders", ["type", "state", "market_id"], name: "index_orders_on_type_and_state_and_market_id", using: :btree
  add_index "orders", ["type", "state", "member_id"], name: "index_orders_on_type_and_state_and_member_id", using: :btree

  create_table "partial_trees", force: :cascade do |t|
    t.integer  "proof_id",   limit: 4,     null: false
    t.integer  "account_id", limit: 4,     null: false
    t.text     "json",       limit: 65535, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "sum",        limit: 255
  end

  create_table "payment_addresses", force: :cascade do |t|
    t.string   "currency_id", limit: 10,                  null: false
    t.integer  "account_id",  limit: 4,                   null: false
    t.string   "address",     limit: 64
    t.string   "secret",      limit: 128
    t.string   "details",     limit: 1024, default: "{}", null: false
    t.datetime "created_at",                              null: false
    t.datetime "updated_at",                              null: false
  end

  add_index "payment_addresses", ["account_id"], name: "index_payment_addresses_on_account_id", unique: true, using: :btree
  add_index "payment_addresses", ["currency_id", "address"], name: "index_payment_addresses_on_currency_id_and_address", unique: true, using: :btree
  add_index "payment_addresses", ["currency_id"], name: "index_payment_addresses_on_currency_id", using: :btree

  create_table "proofs", force: :cascade do |t|
    t.string   "root",        limit: 255
    t.string   "currency_id", limit: 10
    t.boolean  "ready",                     default: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "sum",         limit: 255
    t.text     "addresses",   limit: 65535
    t.string   "balance",     limit: 30
  end

  add_index "proofs", ["currency_id"], name: "index_proofs_on_currency_id", using: :btree

  create_table "trades", force: :cascade do |t|
    t.decimal  "price",                    precision: 32, scale: 16, null: false
    t.decimal  "volume",                   precision: 32, scale: 16, null: false
    t.integer  "ask_id",        limit: 4,                            null: false
    t.integer  "bid_id",        limit: 4,                            null: false
    t.integer  "trend",         limit: 4,                            null: false
    t.string   "market_id",     limit: 10,                           null: false
    t.integer  "ask_member_id", limit: 4,                            null: false
    t.integer  "bid_member_id", limit: 4,                            null: false
    t.decimal  "funds",                    precision: 32, scale: 16, null: false
    t.datetime "created_at",                                         null: false
    t.datetime "updated_at",                                         null: false
  end

  add_index "trades", ["ask_id"], name: "index_trades_on_ask_id", using: :btree
  add_index "trades", ["ask_member_id", "bid_member_id"], name: "index_trades_on_ask_member_id_and_bid_member_id", using: :btree
  add_index "trades", ["bid_id"], name: "index_trades_on_bid_id", using: :btree
  add_index "trades", ["market_id", "created_at"], name: "index_trades_on_market_id_and_created_at", using: :btree

  create_table "versions", force: :cascade do |t|
    t.string   "item_type",  limit: 255,   null: false
    t.integer  "item_id",    limit: 4,     null: false
    t.string   "event",      limit: 255,   null: false
    t.string   "whodunnit",  limit: 255
    t.text     "object",     limit: 65535
    t.datetime "created_at"
  end

  add_index "versions", ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id", using: :btree

  create_table "withdraws", force: :cascade do |t|
    t.integer  "account_id",   limit: 4,                             null: false
    t.integer  "member_id",    limit: 4,                             null: false
    t.string   "currency_id",  limit: 10,                            null: false
    t.decimal  "amount",                   precision: 32, scale: 16, null: false
    t.decimal  "fee",                      precision: 32, scale: 16, null: false
    t.string   "txid",         limit: 128
    t.string   "aasm_state",   limit: 30,                            null: false
    t.decimal  "sum",                      precision: 32, scale: 16, null: false
    t.string   "type",         limit: 30,                            null: false
    t.string   "tid",          limit: 64,                            null: false
    t.string   "rid",          limit: 64,                            null: false
    t.datetime "created_at",                                         null: false
    t.datetime "updated_at",                                         null: false
    t.datetime "completed_at"
  end

  add_index "withdraws", ["aasm_state"], name: "index_withdraws_on_aasm_state", using: :btree
  add_index "withdraws", ["account_id"], name: "index_withdraws_on_account_id", using: :btree
  add_index "withdraws", ["currency_id", "txid"], name: "index_withdraws_on_currency_id_and_txid", unique: true, using: :btree
  add_index "withdraws", ["currency_id"], name: "index_withdraws_on_currency_id", using: :btree
  add_index "withdraws", ["member_id"], name: "index_withdraws_on_member_id", using: :btree
  add_index "withdraws", ["tid"], name: "index_withdraws_on_tid", using: :btree
  add_index "withdraws", ["type"], name: "index_withdraws_on_type", using: :btree

end
