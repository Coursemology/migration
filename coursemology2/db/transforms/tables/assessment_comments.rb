def transform_assessment_comments(course_ids = [])
  transform_table :comment_topics,
                  to: ::Course::Assessment::SubmissionQuestion,
                  default_scope: proc { within_courses(course_ids) } do
    before_transform do |old|
      if old.topic.present?
        sq = ::Course::Assessment::SubmissionQuestion.find_by(submission_id: old.transform_submission_id, question_id: old.transform_question_id)
        if sq
          # Memorize the result if target exists
          old.class.memoize_transform(old.id, sq.id)
          false
        else
          true
        end
      else
        false
      end
    end

    primary_key :id
    column :transform_course_id, to: :course_id
    column :pending, to: :pending_staff_reply
    column :transform_submission_id, to: :submission_id
    column :transform_question_id, to: :question_id

    column :created_at, to: :created_at do |old|
      acting_as.created_at = old
      old
    end
    column to: :updated_at do
      # Topic updated time should be set to the last commented at
      acting_as.updated_at = source_record.last_commented_at || source_record.updated_at
      source_record.updated_at
    end

    skip_saving_unless_valid
  end

  transform_table :comments,
                  to: ::Course::Discussion::Post,
                  default_scope: proc { within_courses(course_ids) } do
    primary_key :id
    column :transform_topic_id, to: :topic_id
    column to: :title do
      '(No Title)'
    end
    column to: :text do
      ContentParser.parse_mc_tags(source_record.text)
    end
    column to: :creator_id do
      result = source_record.transform_creator_id
      self.updater_id = result
      result
    end
    column :created_at
    column :updated_at

    skip_saving_unless_valid
  end

  transform_table :annotations,
                  to: ::Course::Discussion::Post,
                  default_scope: proc { within_courses(course_ids) } do
    primary_key :id
    column to: :topic do
      file = source_record.transform_file
      if file
        new_course_id = V1::Source::Course.transform(source_record.assessment_answer.std_course.course_id)
        Course::Assessment::Answer::ProgrammingFileAnnotation.new(
          file: file, line: source_record.line_start, course_id: new_course_id,
          created_at: source_record.created_at, updated_at: source_record.updated_at
        ).discussion_topic
      end
    end
    column to: :title do
      '(No Title)'
    end
    column to: :text do
      ContentParser.parse_mc_tags(source_record.text)
    end
    column to: :creator_id do
      result = source_record.transform_creator_id
      self.updater_id = result
      result
    end
    column :created_at
    column :updated_at

    skip_saving_unless_valid
  end
end

# Schema
#
# V2:
#
# create_table "course_assessment_submission_questions", force: :cascade do |t|
#   t.integer  "submission_id", :null=>false, :index=>{:name=>"fk__course_assessment_submission_questions_submission_id"}, :foreign_key=>{:references=>"course_assessment_submissions", :name=>"fk_course_assessment_submission_questions_submission_id", :on_update=>:no_action, :on_delete=>:no_action}
#   t.integer  "question_id",   :null=>false, :index=>{:name=>"fk__course_assessment_submission_questions_question_id"}, :foreign_key=>{:references=>"course_assessment_questions", :name=>"fk_course_assessment_submission_questions_question_id", :on_update=>:no_action, :on_delete=>:no_action}
#   t.datetime "created_at",    :null=>false
#   t.datetime "updated_at",    :null=>false
# end
# add_index "course_assessment_submission_questions", ["submission_id", "question_id"], :name=>"idx_course_assessment_submission_questions_on_sub_and_qn", :unique=>true
#
# create_table "course_assessment_answer_programming_file_annotations", force: :cascade do |t|
#   t.integer "file_id", null: false, index: {name: "fk__course_assessment_answe_09c4b638af92d0f8252d7cdef59bd6f3"}, foreign_key: {references: "course_assessment_answer_programming_files", name: "fk_course_assessment_answer_ed21459e7a2a5034dcf43a14812cb17d", on_update: :no_action, on_delete: :no_action}
#   t.integer "line",    null: false
# end
#
# create_table "course_discussion_topics", force: :cascade do |t|
#   t.integer  "actable_id"
#   t.string   "actable_type",        :limit=>255, :index=>{:name=>"index_course_discussion_topics_on_actable_type_and_actable_id", :with=>["actable_id"], :unique=>true}
#   t.integer  "course_id",           :null=>false, :index=>{:name=>"fk__course_discussion_topics_course_id"}, :foreign_key=>{:references=>"courses", :name=>"fk_course_discussion_topics_course_id", :on_update=>:no_action, :on_delete=>:no_action}
#   t.boolean  "pending_staff_reply", :default=>false, :null=>false
#   t.datetime "created_at",          :null=>false
#   t.datetime "updated_at",          :null=>false
# end

# create_table "course_discussion_posts", force: :cascade do |t|
#   t.integer  "parent_id",  :index=>{:name=>"fk__course_discussion_posts_parent_id"}, :foreign_key=>{:references=>"course_discussion_posts", :name=>"fk_course_discussion_posts_parent_id", :on_update=>:no_action, :on_delete=>:no_action}
#   t.integer  "topic_id",   :null=>false, :index=>{:name=>"fk__course_discussion_posts_topic_id"}, :foreign_key=>{:references=>"course_discussion_topics", :name=>"fk_course_discussion_posts_topic_id", :on_update=>:no_action, :on_delete=>:no_action}
#   t.string   "title",      :limit=>255
#   t.text     "text"
#   t.integer  "creator_id", :null=>false, :index=>{:name=>"fk__course_discussion_posts_creator_id"}, :foreign_key=>{:references=>"users", :name=>"fk_course_discussion_posts_creator_id", :on_update=>:no_action, :on_delete=>:no_action}
#   t.integer  "updater_id", :null=>false, :index=>{:name=>"fk__course_discussion_posts_updater_id"}, :foreign_key=>{:references=>"users", :name=>"fk_course_discussion_posts_updater_id", :on_update=>:no_action, :on_delete=>:no_action}
#   t.datetime "created_at", :null=>false
#   t.datetime "updated_at", :null=>false
# end

# V1:
#
# create_table "comment_topics", :force => true do |t|
#   t.integer  "course_id"
#   t.integer  "topic_id"
#   t.string   "topic_type" // Assessment::Answer, etc.. Duplicated with commentable_id and annotable_id
#   t.datetime "last_commented_at"
#   t.boolean  "pending"
#   t.string   "permalink"
#   t.datetime "created_at",        :null => false
#   t.datetime "updated_at",        :null => false
# end
#
# create_table "comments", :force => true do |t|
#   t.integer  "user_course_id"
#   t.text     "text"
#   t.integer  "commentable_id"
#   t.string   "commentable_type"
#   t.datetime "created_at",       :null => false
#   t.datetime "updated_at",       :null => false
#   t.time     "deleted_at"
#   t.integer  "comment_topic_id"
# end
#
# create_table "annotations", :force => true do |t|
#   t.integer  "annotable_id"
#   t.string   "annotable_type"
#   t.integer  "line_start"
#   t.integer  "line_end"
#   t.integer  "user_course_id"
#   t.text     "text"
#   t.datetime "created_at",     :null => false
#   t.datetime "updated_at",     :null => false
#   t.time     "deleted_at"
# end