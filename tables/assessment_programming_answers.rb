class AssessmentProgrammingAnswerTable < BaseTable
  table_name 'assessment_coding_answers'
  scope { |ids| within_courses(ids).with_eager_load }

  def migrate_batch(batch)
    batch.each do |old|
      new = ::Course::Assessment::Answer::Programming.new

      migrate(old, new) do
        column :submission_id do
          store.get(V1::AssessmentSubmission.table_name, old.submission_id)
        end
        column :question_id do
          old.transform_question_id(store)
        end
        column :transform_workflow_state => :workflow_state
        column :transform_submitted_at => :submitted_at
        column :transform_grade => :grade
        column :correct
        column :grader_id do
          if new.graded?
            id = nil
            if old.assessment_answer_grading
              id = store.get(V1::User.table_name, old.assessment_answer_grading.grader_id)
            end
            id || User::SYSTEM_USER_ID
          end
        end
        column :transform_graded_at => :graded_at
        column :updated_at do
          old.assessment_answer.updated_at
        end
        column :transform_created_at => :created_at

        if old.content.present?
          # There are strings ends with "\u0000" which result in a postgres error.
          new.files.build(filename: 'template.py', content: old.content.sub("\u0000", ''))
        end

        if skip_validation?
          new.save!(validate: false)
        else
          skip_saving_unless_valid
        end

        store.set(V1::AssessmentAnswer.table_name, old.assessment_answer.id, new.acting_as.id)
        store.set(model.table_name, old.id, new.id) if new.persisted?
      end
    end
  end

  def skip_validation?
    # From the log there's no validation for these courses, skip to improve performance
     [97, 149, 150, 253, 361, 453, 517].include?(course_ids[0])
  end

  def process_in_batches?
    # From testing, find_in_batches breaks for course 97 and 150
    super && ![97, 150].include?(course_ids[0])
  end
end

# Schema
#
# V2:
# create_table "course_assessment_answers", force: :cascade do |t|
#   t.integer  "actable_id"
#   t.string   "actable_type",   :limit=>255, :index=>{:name=>"index_course_assessment_answers_actable", :with=>["actable_id"], :unique=>true}
#   t.integer  "submission_id",  :null=>false, :index=>{:name=>"fk__course_assessment_answers_submission_id"}, :foreign_key=>{:references=>"course_assessment_submissions", :name=>"fk_course_assessment_answers_submission_id", :on_update=>:no_action, :on_delete=>:no_action}
#   t.integer  "question_id",    :null=>false, :index=>{:name=>"fk__course_assessment_answers_question_id"}, :foreign_key=>{:references=>"course_assessment_questions", :name=>"fk_course_assessment_answers_question_id", :on_update=>:no_action, :on_delete=>:no_action}
#   t.string   "workflow_state", :limit=>255, :null=>false
#   t.datetime "submitted_at"
#   t.decimal  "grade",          :precision=>4, :scale=>1
#   t.boolean  "correct",        :comment=>"Correctness is independent of the grade (depends on the grading schema)"
#   t.integer  "grader_id",      :index=>{:name=>"fk__course_assessment_answers_grader_id"}, :foreign_key=>{:references=>"users", :name=>"fk_course_assessment_answers_grader_id", :on_update=>:no_action, :on_delete=>:no_action}
#   t.datetime "graded_at"
#   t.datetime "created_at",     :null=>false
#   t.datetime "updated_at",     :null=>false
# end
# create_table "course_assessment_answer_programming", force: :cascade do |t|
# end
# create_table "course_assessment_answer_programming_files", force: :cascade do |t|
#   t.integer "answer_id", null: false, index: {name: "fk__course_assessment_answer_programming_files_answer_id"}, foreign_key: {references: "course_assessment_answer_programming", name: "fk_course_assessment_answer_programming_files_answer_id", on_update: :no_action, on_delete: :no_action}
#   t.string  "filename",  limit: 255,              null: false
#   t.text    "content",   default: "", null: false
# end
# V1
# create_table "assessment_answers", :force => true do |t|
#   t.integer  "as_answer_id"
#   t.string   "as_answer_type"
#   t.integer  "submission_id"
#   t.integer  "question_id"
#   t.integer  "std_course_id"
#   t.text     "content",        :limit => 16777215
#   t.integer  "attempt_left",                       :default => 0
#   t.boolean  "finalised",                          :default => false
#   t.boolean  "correct",                            :default => false
#   t.datetime "deleted_at"
#   t.datetime "created_at",                                            :null => false
#   t.datetime "updated_at",                                            :null => false
# end
# create_table "assessment_coding_answers", :force => true do |t|
#   t.text     "result"
#   t.datetime "deleted_at"
#   t.datetime "created_at", :null => false
#   t.datetime "updated_at", :null => false
# end
# create_table "assessment_answer_gradings", :force => true do |t|
#   t.integer  "answer_id"
#   t.integer  "grading_id"
#   t.integer  "grader_id"
#   t.integer  "grader_course_id"
#   t.float    "grade"
#   t.datetime "deleted_at"
#   t.datetime "created_at",       :null => false
#   t.datetime "updated_at",       :null => false
# end
