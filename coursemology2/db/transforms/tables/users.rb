def transform_users
  transform_table :users, to: ::User, default_scope: proc { all } do
    before_transform do |old|
      v2_email = User::Email.find_by(email: old.email)
      if v2_email
        # Correct the confirmed at
        if v2_email.confirmed_at.present? && old.confirmed_at.present? && old.confirmed_at < v2_email.confirmed_at
          v2_email.update_column(:confirmed_at, old.confirmed_at)
        end
        V1::Source::User.memoize_transform(old.id, v2_email.user_id)
        false
      else
        true
      end
    end

    primary_key :id
    column :name
    column :email do |old_email|
      self.email = old_email
      if source_record.confirmed_at.present?
        primary_email_record.confirmed_at = source_record.confirmed_at
      else
        skip_confirmation_notification!
      end
    end
    # TODO: Improve performance for user profile photos.
    column :profile_photo_url do
      photo_file = source_record.transform_profile_photo
      if photo_file
        self.profile_photo = photo_file
        photo_file.close unless photo_file.closed?
      end
    end
    column :encrypted_password
    column :sign_in_count
    column :current_sign_in_at
    column :last_sign_in_at
    column :current_sign_in_ip
    column :last_sign_in_ip
    column :system_role_id, to: :role do |old_role|
      case old_role
      when 1
        self.role = 1
      else
        self.role = 0
      end
    end
    column :uid do
      if source_record.uid.present? && source_record.provider == 'facebook'
        auth = { provider: 'facebook', uid: source_record.uid }
        # The check is for that some users are migrated to v2 and changed their email
        if User::Identity.where(auth).count == 0
          link_with_omniauth(auth)
        end
      end
    end
    column to: :time_zone do
      source_record.time_zone || 'Singapore'
    end

    save validate: false
  end
end

# create_table "users", :force => true do |t|
#   t.string   "name"
#   t.string   "profile_photo_url"
#   t.string   "display_name"
#   t.datetime "created_at",                                                       :null => false
#   t.datetime "updated_at",                                                       :null => false
#   t.string   "email",                                         :default => "",    :null => false
#   t.string   "encrypted_password",                            :default => "",    :null => false
#   t.string   "reset_password_token"
#   t.datetime "reset_password_sent_at"
#   t.datetime "remember_created_at"
#   t.integer  "sign_in_count",                                 :default => 0
#   t.datetime "current_sign_in_at"
#   t.datetime "last_sign_in_at"
#   t.string   "current_sign_in_ip"
#   t.string   "last_sign_in_ip"
#   t.integer  "system_role_id"
#  [1, "superuser"],
#  [2, "normal"],
#  [3, "lecturer"],
#  [4, "ta"],
#  [5, "student"],
#  [6, "shared"]
#   t.time     "deleted_at"
#   t.string   "provider"
#   t.string   "uid"
#   t.string   "unconfirmed_email"
#   t.string   "confirmation_token"
#   t.datetime "confirmed_at"
#   t.datetime "confirmation_sent_at"
#   t.boolean  "is_logged_in",                                  :default => true
#   t.boolean  "is_pending_deletion",                           :default => false
#   t.boolean  "use_uploaded_picture",                          :default => false
#   t.integer  "fb_publish_actions_request_count", :limit => 1, :default => 0,     :null => false
#   t.string   "time_zone"
# end

# V2:
# create_table "users", force: :cascade do |t|
#   t.string   "name",                   limit: 255,              null: false
#   t.integer  "role",                   default: 0,  null: false
#   t.text     "profile_photo"
#   t.string   "encrypted_password",     limit: 255, default: "", null: false
#   t.string   "authentication_token",   limit: 255, index: {name: "index_users_on_authentication_token", unique: true}
#   t.string   "reset_password_token",   limit: 255, index: {name: "index_users_on_reset_password_token", unique: true}
#   t.datetime "reset_password_sent_at"
#   t.datetime "remember_created_at"
#   t.integer  "sign_in_count",          default: 0,  null: false
#   t.datetime "current_sign_in_at"
#   t.datetime "last_sign_in_at"
#   t.inet     "current_sign_in_ip"
#   t.inet     "last_sign_in_ip"
#   t.datetime "created_at",             null: false
#   t.datetime "updated_at",             null: false
# end

# Roles
# V1: { superuser: 1, normal: 2, lecturer: 3, ta: 4, student: 5, shared: 6 }
# V2: { normal: 0, administrator: 1, auto_grader: 2 } (For users)
#
