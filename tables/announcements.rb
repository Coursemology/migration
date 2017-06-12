class AnnouncementTable < BaseTable
  table_name 'announcements'
  scope { |ids| within_courses(ids) }

  def migrate_batch(batch)
    batch.each do |old|
      new = ::Course::Announcement.new
      
      migrate(old, new) do
        column :course_id do
          store.get(V1::Course.table_name, old.course_id)
        end
        column :title do
          # some of the announcements don't have titles,
          # example: http://coursemology.org/courses/193/announcements
          title = old.title
          title.present? ? title : 'Untitled'
        end
        column :content do
          description = ContentParser.parse_mc_tags(old.description)
          description, references = ContentParser.parse_images(old, description)
          new.attachment_references = references if references.any?
          description
        end
        column :publish_at => :start_at
        column :end_at do
          old.expiry_at || Time.now
        end
        column :creator_id do
          result = store.get(V1::User.table_name, old.creator_id)
          new.updater_id = result
          result
        end
        column :updated_at
        column :created_at

        skip_saving_unless_valid
        old.migrate_seen_by_users(store, old, new)

        store.set(model.table_name, old.id, new.id)
      end
    end
  end
end

# Schema
#
# V2:
# create_table "course_announcements", force: :cascade do |t|
#   t.integer  "course_id",  :null=>false, :index=>{:name=>"fk__course_announcements_course_id"}, :foreign_key=>{:references=>"courses", :name=>"fk_course_announcements_course_id", :on_update=>:no_action, :on_delete=>:no_action}
#   t.string   "title",      :limit=>255, :null=>false
#   t.text     "content"
#   t.boolean  "sticky",     :default=>false, :null=>false
#   t.datetime "start_at",   :null=>false
#   t.datetime "end_at",     :null=>false
#   t.integer  "creator_id", :null=>false, :index=>{:name=>"fk__course_announcements_creator_id"}, :foreign_key=>{:references=>"users", :name=>"fk_course_announcements_creator_id", :on_update=>:no_action, :on_delete=>:no_action}
#   t.integer  "updater_id", :null=>false, :index=>{:name=>"fk__course_announcements_updater_id"}, :foreign_key=>{:references=>"users", :name=>"fk_course_announcements_updater_id", :on_update=>:no_action, :on_delete=>:no_action}
#   t.datetime "created_at", :null=>false
#   t.datetime "updated_at", :null=>false
# end

# V1
# create_table "announcements", :force => true do |t|
#   t.integer  "creator_id"
#   t.integer  "course_id"
#   t.datetime "publish_at"
#   t.integer  "important"
#   t.datetime "created_at",  :null => false
#   t.datetime "updated_at",  :null => false
#   t.string   "title"
#   t.text     "description"
#   t.time     "deleted_at"
#   t.datetime "expiry_at"
# end