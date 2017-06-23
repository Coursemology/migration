class CourseTable < BaseTable
  table_name 'courses'
  scope { |ids| where(id: ids) }

  def self.get_new_id(old_id)
    # there are 616 courses in v1 now, course 110 - 616 will have the same id on v2, course 1 - 109 will become 701 to 809
    new_id = old_id >= 110 ? old_id : old_id + 700
  end

  def initialize(store, logger, ids, options = {})
    super(store, logger, ids, 1)
    @course_ids = Array(ids)
    @fix_id = options[:fix_id].nil? ? true : options[:fix_id]
  end

  def run
    super

    course_ids.map { |id| store.get(model.table_name, id) }
  end

  def migrate_batch(batch)
    batch.each do |old|
      new = ::Course.new

      migrate(old, new) do
        column :id do
          # Instance variable not accessible
          @fix_id ? CourseTable.get_new_id(old.id) : nil
        end

        column :creator_id do
          store.get(V1::User.table_name, old.creator_id)
        end
        column :title do
          old.title.present? ? old.title : 'Untitled'
        end
        column :description
        column :is_publish => :published
        column :is_open => :enrollable

        column :assessment_categories do
          migrate_sidebar_settings(old, new)
          build_assessment_categories(old, new)
        end

        column :gamified do
          old.pref(:sidebar_show_gamification_elements)
        end unless old.has_no_prefs?

        column :start_at do
          old.start_at || old.created_at
        end
        column :end_at do
          old.end_at || Time.now
        end
        column :updated_at
        column :created_at

        logo_file = old.transform_logo(logger)
        if logo_file
          if File.extname(logo_file.path).blank?
            logo_file.close
            # it seems that png works for all courses, need to double check after migration
            new_path = logo_file.path + '.png'
            FileUtils.cp(logo_file.path, new_path)
            logo_file = File.new(new_path)
            logger.log("Missing logo extension: Course #{old.id}")
          end

          if File.extname(logo_file.path) == '.jfif'
            logo_file.close
            new_path = logo_file.path.gsub(/jfif\z/, 'jpeg')
            FileUtils.cp(logo_file.path, new_path)
            logo_file = File.new(new_path)
            logger.log("Changed logo file extension from JFIF to JPEG: Course #{old.id}")
          end

          new.logo = logo_file
          logo_file.close unless logo_file.closed?
        end

        new.root_folder.created_at = old.root_folder&.created_at || old.created_at
        new.root_folder.updated_at = old.root_folder&.updated_at || old.created_at
        level = new.levels.first
        level.created_at = old.created_at
        level.updated_at = old.updated_at

        # settings required mission category id, so save once before migrating settings
        skip_saving_unless_valid
        if new.persisted?
          migrate_settings(old, new)
          new.save!
        end

        store.set(model.table_name, old.id, new.id)
      end
    end
  end

  # Insert each CoursePreference setting into the destination course setting tree.
  def migrate_settings(source, destination)
    return if source.has_no_prefs?

    # Allow each assessment category to be set independently
    training_category_id = destination.assessment_categories.find_by(title: source.training_pref.name).id.to_s
    mission_category_id = destination.assessment_categories.find_by(title: source.mission_pref.name).id.to_s

    # Generates a hash that is meant to be merged into a subtree of the course settings tree.
    # Settings that match the default setting for a given key are ignored.
    #
    # Example:
    # mapping = [
    #   [:v1_funky_setting_key, :v2_key, "default value"],
    #   [:v1_funky_setting_key2, :v2_key2, "default value 2"],
    #   ...
    # ]
    # intermediate_keys = [:a, :b, :c]
    #
    # Returned value, if values are not the default:
    # {
    #   v2_key: { a: { b: { c: source.pref(:v1_funky_setting_key) } } },
    #   v2_key2: { a: { b: { c: source.pref(:v1_funky_setting_key2) } } },
    #   ...
    # }
    #
    # @param [Array] mapping
    # @param [Array] intermediate_keys
    # @return [Hash]
    non_default_settings_hash = -> (mapping, intermediate_keys) do
      mapping.reduce({}) do |settings, setting_item|
        old_key, new_key, default = setting_item
        value = source.pref(old_key)
        if value == default
          settings
        else
          nested_value = intermediate_keys.reverse.reduce(value) { |acc, key| { key => acc } }
          settings.merge({ new_key => nested_value })
        end
      end
    end

    # Sets the settings on the destination course if it is not the default setting.
    set_unless_default = -> (key_array, source_setting_key, default_value) do
      value = source.pref(source_setting_key)
      destination.settings(*key_array[0...-1]).public_send("#{key_array.last}=", value) unless value == default_value
    end

    ###################################
    # Migrate Training page table settings
    ###################################
    training_column_header_mapping = [
      [:training_column_header_title, :title, "Training"],
      [:training_column_header_tag, :skills, "Tag"],
      [:training_column_header_exp, :base_exp, "Max Exp"],
      [:training_column_header_award, :requirement_for, "Requirement for"],
      [:training_column_header_start, :start_at, "Start Time"],
      [:training_column_header_end, :end_at, "End Time"],
      [:training_column_header_bonus_exp, :time_bonus_exp, "Bonus EXP"],
      [:training_column_header_bonus_cutoff, :bonus_end_at, "Bonus Cutoff"],
    ]
    training_column_visibility_mapping = [
      [:training_column_show_title, :title, true],
      [:training_column_show_exp, :base_exp, true],
      [:training_column_show_award, :requirement_for, true],
      [:training_column_show_start, :start_at, true],
      [:training_column_show_end, :end_at, false],
      [:training_column_show_bonus_exp, :time_bonus_exp, true],
      [:training_column_show_bonus_cutoff, :bonus_end_at, true],
    ]
    training_column_headers = non_default_settings_hash.call(training_column_header_mapping, [:header])
    training_column_visibilities = non_default_settings_hash.call(training_column_visibility_mapping, [:visible])
    training_columns = training_column_headers.deep_merge(training_column_visibilities)
    destination.settings(:course_assessments_component, training_category_id).columns = training_columns unless training_columns.empty?

    ###################################
    # Migrate Mission page table settings
    ###################################
    mission_column_header_mapping = [
      [:mission_column_header_title, :title, "Mission"],
      [:mission_column_header_tag, :skills, "Tag"],
      [:mission_column_header_exp, :base_exp, "Max Exp"],
      [:mission_column_header_award, :requirement_for, "Requirement for"],
      [:mission_column_header_start, :start_at, "Start Time"],
      [:mission_column_header_end, :end_at, "End Time"],
    ]

    mission_column_visibility_mapping = [
      [:mission_column_show_title, :title, true],
      [:mission_column_show_exp, :base_exp, true],
      [:mission_column_show_award, :requirement_for, true],
      [:mission_column_show_start, :start_at, true],
      [:mission_column_show_end, :end_at, true],
    ]
    mission_column_headers = non_default_settings_hash.call(mission_column_header_mapping, [:header])
    mission_column_visibilities = non_default_settings_hash.call(mission_column_visibility_mapping, [:visible])
    mission_columns = mission_column_headers.deep_merge(mission_column_visibilities)
    destination.settings(:course_assessments_component, mission_category_id).columns = mission_columns unless mission_columns.empty?

    ######################################
    # Migrate Assessment Datetime Formats
    ######################################
    set_unless_default.call([:course_assessments_component, mission_category_id, :datetime_format], :mission_datetime_format, '%d-%m-%Y')
    set_unless_default.call([:course_assessments_component, training_category_id, :datetime_format], :training_datetime_format, '%d-%m-%Y')

    ###################################
    # Migrate Email Settings
    ###################################
    training_email_mapping = [
      [:email_new_comment, :new_comment, true],
      [:email_new_mission, :assessment_opened, true],
    ]
    training_email_defaults = {
      grades_released: { enabled: false },
      new_submission: { enabled: false },
      assessment_closing: { enabled: false }
    }
    training_emails = non_default_settings_hash.call(training_email_mapping, [:enabled]).merge(training_email_defaults)
    destination.settings(:course_assessments_component, training_category_id).emails = training_emails

    mission_email_mapping = [
      [:email_new_comment, :new_comment, true],
      [:email_new_grading, :grades_released, true],
      [:email_new_submission, :new_submission, true],
      [:email_new_training, :assessment_opened, true],
      [:email_mission_due, :assessment_closing, true],
    ]
    mission_emails = non_default_settings_hash.call(mission_email_mapping, [:enabled])
    destination.settings(:course_assessments_component, mission_category_id).emails = mission_emails unless mission_emails.empty?

    # Notify students when their enrollment request is approved
    set_unless_default.call([:course_users_component, :emails, :enrol_request_approved, :enabled], :email_new_student, true)
    # Notify lecturer(s) for new enrollment request
    set_unless_default.call([:course_users_component, :emails, :new_enrol_request, :enabled], :email_new_enroll_request, true)
    # Notify all staff and students for new announcement
    set_unless_default.call([:course_announcements_component, :emails, :new_announcement, :enabled], :email_new_announcement, true)

    ###################################
    # Migrate MCQ auto-grader settings
    ###################################
    set_unless_default.call(
      [:course_assessments_component, training_category_id, :autograder_type],
      :multiple_choice_question_auto_grader_type, 'default'
    )

    ###################################
    # Migrate training Reattempt settings
    ###################################
    set_unless_default.call(
      [:course_assessments_component, training_category_id, :reattempt_allowed],
      :training_reattempt_allowed, true
    )
    # There are some negative values, though in each case, reattempt is disabled.
    reattempt_percentage_earnable = source.pref(:training_reattempt_percentage_earnable).to_i
    unless reattempt_percentage_earnable == 20
      destination.settings(:course_assessments_component, training_category_id).reattempt_percentage_earnable =
        [reattempt_percentage_earnable, 0].max
    end

    ###################################
    # Migrate Leaderboard student count
    ###################################
    set_unless_default.call([:course_leaderboard_component, :display_user_count], :leaderboard_student_count, "30")

    ###################################
    # Migrate Course Homepage Settings
    ###################################
    set_unless_default.call([:course, :homepage, :announcements, :enabled], :homepage_show_announcements, true)
    set_unless_default.call([:course, :homepage, :announcements, :count], :homepage_announcement_count, "3")
    set_unless_default.call([:course, :homepage, :announcements, :title], :homepage_show_announcements_title, "Announcements")
    set_unless_default.call([:course, :homepage, :activity_feed, :enabled], :homepage_show_activity_feed, true)
    set_unless_default.call([:course, :homepage, :activity_feed, :count], :homepage_activity_feed_count, "50")
    set_unless_default.call([:course, :homepage, :activity_feed, :title], :homepage_show_activity_feed_title, "Notable Happenings")

    ###################################
    # Migrate Achievement locked icon setting
    ###################################
    set_unless_default.call(
      [:course_achievements_component, :show_greyscale_badge],
      :achievements_display_greyed_icon_instead_of_lock, true
    )

    ###################################
    # Migrate pagination setting
    ###################################
    set_unless_default.call([:course_announcements_component, :pagination], :paginate_announcements_count, '50')
    set_unless_default.call([:course_discussion_topics_component, :pagination], :paginate_comments_count, '50')
    set_unless_default.call([:course_forums_component, :pagination], :paginate_forums_count, '20')

    ###################################
    # Migrate PDF export setting
    ###################################
    set_unless_default.call(
      [:course_assessments_component, mission_category_id, :allow_pdf_export],
      :mission_allow_pdf_export, false
    )
    set_unless_default.call(
      [:course_assessments_component, training_category_id, :allow_pdf_export],
      :training_allow_pdf_export, false
    )

    ###################################
    # Migrate course user name change setting
    ###################################
    set_unless_default.call([:course_users_component, :allow_course_user_change_name], :allow_course_user_change_name, true)

    ###################################
    # Migrate Self Directed Learning setting
    ###################################
    destination.settings(:course).advance_start_at_duration = 366.days if source.pref(:self_directed_learning)
  end

  def build_assessment_categories(source, destination)
    if destination.assessment_categories.length == 0 || destination.assessment_categories.length > 1
      raise 'No category or more than 1 categories found'
    end

    training_pref = source.training_pref
    default_category = destination.assessment_categories.first
    default_category.assign_attributes(
      title: training_pref.name,
      weight: training_pref.pos || 2,

      creator_id: store.get(V1::User.table_name, source.creator_id),
      updater_id: store.get(V1::User.table_name, source.creator_id),
      created_at: training_pref.created_at || source.created_at,
      updated_at: training_pref.updated_at || source.updated_at
    )

    mission_pref = source.mission_pref
    mission_category = Course::Assessment::Category.new(
      title: mission_pref.name,
      weight: mission_pref.pos || 2,

      creator_id: store.get(V1::User.table_name, source.creator_id),
      updater_id: store.get(V1::User.table_name, source.creator_id),
      created_at: mission_pref.created_at || source.created_at,
      updated_at: mission_pref.updated_at || source.updated_at
    )

    [default_category, mission_category].each do |cat|
      cat.folder.created_at = cat.created_at
      cat.folder.updated_at = cat.updated_at

      tab = cat.tabs.first
      tab.created_at = cat.created_at
      tab.updated_at = cat.updated_at
    end

    [default_category, mission_category]
  end

  def migrate_sidebar_settings(source, destination)
    # V1 Mission and Training sidebar items are migrated in build_assessment_categories
    # V1 Comics sidebar items are dropped

    mapping = {
      'announcements' => { sidebar_key: :announcements, # Key for sidebar settings
                           component_key: :course_announcements_component, # Component index settings
                           default_name: 'Announcements'},
      'achievements' => { sidebar_key: :achievements,
                          component_key: :course_achievements_component,
                          default_name: 'Achievements'},
      'leaderboard' => { sidebar_key: :leaderboard,
                         component_key: :course_leaderboard_component,
                         default_name: 'Leaderboard'},
      'students' => { sidebar_key: :users,
                      component_key: :course_users_component, # To be named more specifically later
                      default_name: 'Students'},
      'submissions' => { sidebar_key: :assessments_submissions,
                         component_key: :sidebar_assessments_submissions, # To be placed under assessments later
                         default_name: 'Submissions'},
      'lesson_plan' => { sidebar_key: :lesson_plan,
                         component_key: :course_lesson_plan_component,
                         default_name: 'Lesson Plan'},
      'materials' => { sidebar_key: :materials,
                       component_key: :course_materials_component,
                       default_name: 'Materials'},
      'forums' => { sidebar_key: :forums,
                    component_key: :course_forums_component,
                    default_name: 'Forums'},
      'surveys' => { sidebar_key: :surveys,
                     component_key: :course_survey_component,
                     default_name: 'Surveys'},
    }
    source.course_navbar_preferences.each do |nav_pref|
      key = nav_pref.item

      # Guilds not migrated as a sidebar item. Instead, if guilds are enabled, turn on group leaderboard.
      if key == 'guilds'
        destination.settings(:course_leaderboard_component, :group_leaderboard).enabled = nav_pref.is_enabled
        next
      end

      next unless item_hash = mapping[key]

      # Sidebar order
      destination.settings(:sidebar, item_hash[:sidebar_key]).weight = nav_pref.pos

      if component_key = item_hash[:component_key]
        # Component enable/disable settings
        destination.settings(:components, component_key).enabled = nav_pref.is_enabled
        destination.settings(:components, component_key).visible = nav_pref.is_displayed

        # Handle individual component settings here
        if nav_pref.name != item_hash[:default_name]
          destination.settings(component_key).title = nav_pref.name
        end
      end
    end
  end
end


######
# V1 #
######

# create_table "courses", :force => true do |t|
#   t.string   "title"
#   t.integer  "creator_id"
#   t.text     "description"
#   t.datetime "created_at",                             :null => false
#   t.datetime "updated_at",                             :null => false
#   t.string   "logo_url"
#   t.string   "banner_url"
#   t.time     "deleted_at"
#   t.boolean  "is_publish",          :default => false
#   t.boolean  "is_open",             :default => true
#   t.boolean  "is_active",           :default => true
#   t.datetime "start_at"
#   t.datetime "end_at"
#   t.boolean  "is_pending_deletion", :default => false
# end

# V1 course settings related tables
#
# create_table "course_preferences", :force => true do |t|
#   t.integer  "course_id"
#   t.integer  "preferable_item_id"
#   t.string   "prefer_value"
#   t.boolean  "display"
#   t.datetime "created_at",         :null => false
#   t.datetime "updated_at",         :null => false
# end
#
# create_table "preferable_items", :force => true do |t|
#   t.string   "item"
#   t.string   "item_type"
#   t.string   "name"
#   t.string   "default_value"
#   t.boolean  "default_display"
#   t.string   "description"
#   t.datetime "created_at",      :null => false
#   t.datetime "updated_at",      :null => false
# end
#
# create_table "course_navbar_preferences", :force => true do |t|
#   t.integer  "course_id"
#   t.integer  "navbar_preferable_item_id"
#   t.integer  "navbar_link_type_id"
#   t.string   "item"
#   t.string   "name"
#   t.boolean  "is_displayed"
#   t.boolean  "is_enabled"
#   t.string   "description"
#   t.string   "link_to"
#   t.integer  "pos"
#   t.datetime "created_at",                :null => false
#   t.datetime "updated_at",                :null => false
# end
#
# create_table "navbar_preferable_items", :force => true do |t|
#   t.string   "item"
#   t.integer  "navbar_link_type_id"
#   t.string   "name"
#   t.boolean  "is_displayed"
#   t.boolean  "is_enabled"
#   t.string   "description"
#   t.string   "link_to"
#   t.integer  "pos"
#   t.datetime "created_at",          :null => false
#   t.datetime "updated_at",          :null => false
# end
#
# create_table "navbar_link_types", :force => true do |t|
#   t.string   "link_type"
#   t.datetime "created_at", :null => false
#   t.datetime "updated_at", :null => false
# end

######
# V2 #
######

# create_table "courses", force: :cascade do |t|
#   t.integer  "instance_id",      :null=>false, :index=>{:name=>"fk__courses_instance_id"}, :foreign_key=>{:references=>"instances", :name=>"fk_courses_instance_id", :on_update=>:no_action, :on_delete=>:no_action}
#   t.string   "title",            :limit=>255, :null=>false
#   t.text     "description"
#   t.text     "logo"
#   t.boolean  "published",        :default=>false, :null=>false
#   t.boolean  "enrollable",       :default=>false, :null=>false
#   t.string   "registration_key", :limit=>16, :index=>{:name=>"index_courses_on_registration_key", :unique=>true}
#   t.text     "settings"
#   t.boolean  "gamified",         :default=>true, :null=>false
#   t.datetime "start_at",         :null=>false
#   t.datetime "end_at",           :null=>false
#   t.integer  "creator_id",       :null=>false, :index=>{:name=>"fk__courses_creator_id"}, :foreign_key=>{:references=>"users", :name=>"fk_courses_creator_id", :on_update=>:no_action, :on_delete=>:no_action}
#   t.integer  "updater_id",       :null=>false, :index=>{:name=>"fk__courses_updater_id"}, :foreign_key=>{:references=>"users", :name=>"fk_courses_updater_id", :on_update=>:no_action, :on_delete=>:no_action}
#   t.datetime "created_at",       :null=>false
#   t.datetime "updated_at",       :null=>false
# end

# Target course settings shape:
#
# {"components"=>
#   {"course_points_disbursement_component"=>{"enabled"=>true},
#    "course_announcements_component"=>{
#     "enabled"=>true,
#     "visible"=>ture,                                                   # added for all components
#    },
#    "course_lesson_plan_component"=>{"enabled"=>true},
#    "course_forums_component"=>{"enabled"=>true},
#    "course_duplication_component"=>{"enabled"=>true},
#    "course_statistics_component"=>{"enabled"=>true},
#    "course_levels_component"=>{"enabled"=>true},
#    "course_assessments_component"=>{"enabled"=>true},
#    "course_discussion_topics_component"=>{"enabled"=>true},
#    "course_groups_component"=>{"enabled"=>true},
#    "course_leaderboard_component"=>{"enabled"=>true},
#    "course_materials_component"=>{"enabled"=>true},
#    "course_achievements_component"=>{"enabled"=>true},
#    "course_courses_component"=>{"enabled"=>false},
#    "course_users_component"=>{"enabled"=>false},
#    "course_videos_component"=>{"enabled"=>true},
#    "course_survey_component"=>{"enabled"=>true},
#    "course_virtual_classrooms_component"=>{"enabled"=>false}},
#
#  "sidebar"=>
#   {"assessments"=>{"weight"=>3},
#    "announcements"=>{"weight"=>3},
#    "assessments_submissions"=>{"weight"=>4},
#    "videos"=>{"weight"=>5},
#    "achievements"=>{"weight"=>6},
#    "discussion_topics"=>{"weight"=>7},
#    "leaderboard"=>{"weight"=>8},
#    "users"=>{"weight"=>9},
#    "lesson_plan"=>{"weight"=>10},
#    "materials"=>{"weight"=>11},
#    "forums"=>{"weight"=>12},
#    "surveys"=>{"weight"=>13}},
#
#  "course"=>{
#    "advance_start_at_duration"=>14 days
#    "homepage"=>{...}                                                   # new
#   },
#  "user"=>{"title"=>"Students list"},
#
#  "course_announcements_component"=>{
#     "title"=>"The announcements", "pagination"=>"50"
#     "emails"=>{"new_announcement"=>{"enabled"=>true}}                  # new
#   },
#  "course_forums_component"=>{"title"=>"chatterbox", "pagination"=>"50"},
#  "course_leaderboard_component"=>
#   {"title"=>"The leaderboard",
#    "display_user_count"=>"30",
#    "group_leaderboard"=>{"enabled"=>false}},
#  "course_materials_component"=>{"title"=>"Workbin"},
#  "course_virtual_classrooms_component"=>
#   {"pagination"=>"50",
#    "braincert_whiteboard_api_key"=>"xxxxxxxxxxx",
#    "max_duration"=>"60"},
#                                                                        # below items are all unimplemented
#  "course_assessments_component"=>{
#    "Mission"=>{
#      "columns"={"base_exp"=>{"header"=>"Your Reward"} ...},
#      "datetime_format" => "ago",
#      "emails"=>{"email_new_mission"=>{"enabled"=>true} ...},
#      "allow_pdf_export"=>true,
#    },
#    "Training"=>{
#      "columns"={"base_exp"=>{"visible"=>false} ...}
#      "datetime_format" => "ago",
#      "emails"=>{...},
#      "allow_pdf_export"=>true,
#      "multiple_choice_question_auto_grader_type"=>"two-one-zero",
#      "reattempt_allowed"=>true
#      "reattempt_percentage_earnable"=>"20"
#    }
#  }
#  "course_users_component"=>{
#    "title"=>"Custom Title",
#    "allow_course_user_change_name"=>true,
#    "emails"=>{...}
#  },
#  "course_achievements_component"=>{"show_greyscale_badge"=>false},
#  "sidebar_assessments_submissions"=>{"title"=>"Custom Title"},
#}
