module V1
  def_model 'course_navbar_preferences'

  def_model 'course_preferences'

  def_model 'courses' do
    has_many :course_navbar_preferences, inverse_of: nil
    has_many :course_preferences, inverse_of: nil

    def training_pref
      @training_pref ||= course_navbar_preferences.where(item: 'trainings').first ||
        CourseNavbarPreference.new(name: 'Trainings', pos: 2)
    end

    def mission_pref
      @mission_pref ||= course_navbar_preferences.where(item: 'missions').first ||
        CourseNavbarPreference.new(name: 'Missions', pos: 3)
    end

    def transform_logo(logger)
      if logo_url.present?
        Downloader.download_to_local(logo_url, self, logger)
      end
    end

    def root_folder
      @root_folder ||= MaterialFolder.find_by(course_id: id, parent_folder_id: nil)
    end

    # Each course has a CoursePreference for each of the 68 PreferableItems.
    # A setting might be stored in the `prefer_value` field, `display` boolean or both;
    # The `display` is typically to indicate whether a feature is enabled or not.
    # For ease of understanding, we use the key :enabled instead.
    def preference_hash
      @preference_hash ||= course_preferences.to_a.map do |pref|
        [pref.preferable_item_id, { value: pref.prefer_value, enabled: pref.display }]
      end.to_h
    end

    # The preference_items_hash tags each relevant setting to a human-readable key.
    # PreferableItems are list below in the following format:
    #   [id, item, item_type, name, default_value, default_display]
    def preference_items_hash
      @preference_items_hash ||= {
        # Mission page table headers and visibilities
          # [1, "Mission", "Column", "title", "Mission", true],
          # [2, "Mission", "Column", "tag", "Tag", true],
          # [3, "Mission", "Column", "exp", "Max Exp", true],
          # [4, "Mission", "Column", "award", "Requirement for", true],
          # [5, "Mission", "Column", "start", "Start Time", true],
          # [6, "Mission", "Column", "end", "End Time", true],
        mission_column_header_title: [1, :value],
        mission_column_header_tag: [2, :value],
        mission_column_header_exp: [3, :value],
        mission_column_header_award: [4, :value],
        mission_column_header_start: [5, :value],
        mission_column_header_end: [6, :value],

        mission_column_show_title: [1, :enabled],
        # mission_column_show_tag: [2, :enabled]   # Set to true in v2 since not yet implemented.
        mission_column_show_exp: [3, :enabled],
        mission_column_show_award: [4, :enabled],
        mission_column_show_start: [5, :enabled],
        mission_column_show_end: [6, :enabled],

        # Training page table headers and visibilities
          # [7, "Training", "Column", "title", "Training", true],
          # [8, "Training", "Column", "tag", "Tag", true],
          # [9, "Training", "Column", "exp", "Max Exp", true],
          # [10, "Training", "Column", "award", "Requirement for", true],
          # [11, "Training", "Column", "start", "Start Time", true],
          # [12, "Training", "Column", "end", "End Time", false],
          # [34, "Training", "Column", "bonus-exp", "Bonus EXP", true],
          # [35, "Training", "Column", "bonus-cutoff", "Bonus Cutoff", true],
        training_column_header_title: [7, :value],
        training_column_header_tag: [8, :value],
        training_column_header_exp: [9, :value],
        training_column_header_award: [10, :value],
        training_column_header_start: [11, :value],
        training_column_header_end: [12, :value],
        training_column_header_bonus_exp: [34, :value],
        training_column_header_bonus_cutoff: [35, :value],

        training_column_show_title: [7, :enabled],
        # training_column_show_tag: [8, :enabled],  # Set to true in v2 since not yet implemented.
        training_column_show_exp: [9, :enabled],
        training_column_show_award: [10, :enabled],
        training_column_show_start: [11, :enabled],
        training_column_show_end: [12, :enabled],
        training_column_show_bonus_exp: [34, :enabled],
        training_column_show_bonus_cutoff: [35, :enabled],

        # Sidebar settings have already been migrated from course_navbar_preferences
          # [13, "Sidebar", "Student", "announcements", "Announcements", true],
          # [14, "Sidebar", "Student", "missions", "Missions", true],
          # [15, "Sidebar", "Student", "trainings", "Trainings", true],
          # [16, "Sidebar", "Student", "submissions", "Submissions", true],
          # [17, "Sidebar", "Student", "achievements", "Achievements", true],
          # [18, "Sidebar", "Student", "leaderboard", "Leaderboard", true],
          # [19, "Sidebar", "Student", "students", "Students", true],
          # [31, "Sidebar", "Student", "comments", "Comments", true],
          # [58, "Sidebar", "Student", "surveys", "Surveys", true],
          # [59, "Sidebar", "Student", "materials", "Workbin", true],
          # [60, "Sidebar", "Student", "lesson_plan", "Lesson Plan", true],
          # [61, "Sidebar", "Student", "forums", "Forums", true],
          # [64, "Sidebar", "Student", "comics", "Comics", true],

        # Assessment DateTime format
        # Dropdown menu: one of "%d-%m-%Y", "%d %b %Y %H:%M", "%d-%m-%Y %H:%M:%S", "ago"
          # [20, "Training", "Time", "time_format", "%d-%m-%Y", true], # 30 not default
          # [21, "Mission", "Time", "time_format", "%d-%m-%Y", true], # 26 not default
        training_datetime_format: [20, :value],
        mission_datetime_format: [21, :value],

        # Email notification settings
          # [22, "Email", "Course", "new_comment", "New Comment", true], - Notify user when someone commented on his/her thread
          # [23, "Email", "Course", "new_grading", "New Grading", true], - Notify student for new available mission grading
          # [24, "Email", "Course", "new_submission", "New Submission", true], - Notify student's tutor for new mission submission
          # [25, "Email", "Course", "new_student", "New Student", true], - Notify students when their enrollment request is approved
          # [26, "Email", "Course", "new_enroll_request", "New Enroll Request", true], - Notify lecturer(s) for new enrollment request
          # [27, "Email", "Course", "new_announcement", "New Announcement", true], - Notify all staff and students for new announcement
          # [28, "Email", "Course", "new_mission", "New Mission", true], - Notify all staff and students for new mission available
          # [29, "Email", "Course", "new_training", "New Training", true], - Notify all staff and students for new training available
          # [30, "Email", "Course", "mission_due", "Mission Reminder", true], - Mission due reminder for students who didn't submit yet
        email_new_comment: [22, :enabled],
        email_new_grading: [23, :enabled],
        email_new_submission: [24, :enabled],
        email_new_student: [25, :enabled],
        email_new_enroll_request: [26, :enabled],
        email_new_announcement: [27, :enabled],
        email_new_mission: [28, :enabled],
        email_new_training: [29, :enabled],
        email_mission_due: [30, :enabled],

        # MCQ Autograder - either "default" or "two-one-zero"
          # [32, "Mcq", "AutoGrader", "title", "default", true],
        multiple_choice_question_auto_grader_type: [32, :value],

        # Enable Re-attempt allows students to do training again to get a fraction of the full EXP.
          # [33, "Training", "Re-attempt", "title", "20", true],
        training_reattempt_allowed: [33, :enabled],
        training_reattempt_percentage_earnable: [33, :value],

        #  Number of students to show in leaderboard
          # [36, "Leaderboard", "Display", "leaders", "10", true],
        leaderboard_student_count: [36, :value],

        # Course homepage settings
          # [37, "CourseHome", "Section", "announcements", "Announcements", true],
          # [38, "CourseHome", "Section", "activities", "Notable Happenings", true],
          # [41, "CourseHome", "SectionShow", "announcements_no", "3", true],
          # [42, "CourseHome", "SectionShow", "activities_no", "50", true],
        homepage_show_announcements: [37, :enabled],
        homepage_show_activity_feed: [38, :enabled],
        homepage_show_announcements_title: [37, :value],
        homepage_show_activity_feed_title: [38, :value],
        homepage_announcement_count: [41, :value],
        homepage_activity_feed_count: [42, :value],

        # Unused
          # [39, "Training", "Table", "paging", "10", true],
          # [40, "Mission", "Table", "paging", "10", true],
          # [43, "Announcements", "List", "paging", "10", true],

        # Locked achievements icon display type: Display gray scaled icon( A locked icon will be displayed if unchecked )
          # [44, "Achievements", "Icon", "locked", "", true],
        achievements_display_greyed_icon_instead_of_lock: [44, :enabled],

        # Pagination settings
          # [45, "Paging", "Announcements", "Announcements", "50", true], - Number of announcements to display per page
          # [46, "Paging", "Missions", "Missions", "50", true], - Number of missions to display per page
          # [47, "Paging", "MissionStats", "Mission Statistics", "50", true],
          #    - Number of submission to display on page that lists all submissions for a particular mission.
          # [48, "Paging", "Trainings", "Trainings", "50", true], - Number of trainings to display per page
          # [49, "Paging", "TrainingStats", "Training Statistics", "50", true], - Number of students to display per page
          #    - Number of submission to display on page that lists all submissions for a particular training.
          # [50, "Paging", "MissionSubmissions", "Mission Submissions", "50", true],
          #    - Number of submission to display on page that lists all missions submission in the course
          # [51, "Paging", "TrainingSubmissions", "Training Submissions", "50", true],
          #    - Number of submission to display on page that lists all training submission in the course
          # [52, "Paging", "Comments", "Comments", "50", true], - Number of topics to display per page
          # [53, "Paging", "Achievements", "Achievements", "50", true], - Number of achievements to display per page
          # [54, "Paging", "Students", "Students", "50", true], - Number of students to display per page
          # [55, "Paging", "ManageStudents", "Manage Students", "50", true], - Number of students to display per page
          # [56, "Paging", "StudentSummary", "Student Summary", "50", true], - Number of students to display per page
          # [62, "Paging", "Forums", "Forums", "20", true], - Number of topics to display per forum page
        # Not that important. Port only those settings which have been implemented.
        paginate_announcements_count: [45, :value],
        paginate_comments_count: [52, :value],
        paginate_forums_count: [62, :value],

        # Auto create submissions for missions, special feature for courses that just want to take advantage of Coursemology's social features
        # Courses enabled: [20, 28, 73, 96, 145, 180, 182, 225, 261, 292, 365, 385, 460, 529, 550, 572, 590, 606]
          # [57, "Mission", "Submission", "auto", "", false],
        # Ignore for now

        # Display student's level and achievement status on sidebar?
          # [63, "Sidebar", "Other", "ranking", "", true],
        # Courses disabled: [27, 73, 124, 157, 165, 210, 286, 369, 556]
        #   Most of these are clones of NUS CS2020
        # In each case, it is easily argued that the intent is to turn off gamification altogether.
        sidebar_show_gamification_elements: [63, :enabled],

        # Allow PDF exporting
          # [65, "Mission", "Export", "pdf", "PDF", false],
          # [66, "Training", "Export", "pdf", "PDF", false],
        mission_allow_pdf_export: [65, :enabled],
        training_allow_pdf_export: [66, :enabled],

        # Allow students to change their names within course
          # [67, "UserCourse", "ChangeName", "ChangeName", "", true],
        allow_course_user_change_name: [67, :enabled],

        # Self Directed Learning
        # Allow students to attempt the assessments that start at a future time provided they have fulfilled the prerequisites
          # [68, "Assessment", "StartAt", "IgnoreStartAt", "", false]
        self_directed_learning: [68, :enabled],
      }
    end

    # Looks up the course setting for the given preference item name
    # @param [Symbol] pref_item_name
    def pref(pref_item_name)
      id, key = preference_items_hash[pref_item_name]
      preference_hash[id][key]
    end

    # 9 out of the 438 courses have no course_preferences. The rest have all 68 of them.
    def has_no_prefs?
      @has_no_prefs ||= preference_hash.empty?
    end
  end

  # Don't enroll creator in the course
  ::Course.class_eval { def set_defaults; end }
end
