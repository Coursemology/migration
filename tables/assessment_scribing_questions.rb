class AssessmentScribingQuestionTable < BaseTable
  table_name 'assessment_scribing_questions'
  scope { |ids| within_courses(ids) }

  def migrate_batch(batch)
    batch.each do |old|
      new = ::Course::Assessment::Question::Scribing.new
      migrate(old, new) do
        column :assessment_id do
          original_assessment_id = old.assessment_question.assessments.first.id
          store.get(V1::Assessment.table_name, original_assessment_id)
        end
        column :title do
          old.assessment_question.title
        end
        column :description do
          description = ContentParser.parse_mc_tags(old.assessment_question.description)
          description, references = ContentParser.parse_images(old, description, logger)
          new.question.attachment_references = references if references.any?
          description
        end
        column :maximum_grade do
          old.assessment_question.max_grade.to_i
        end
        column :weight do
          old.assessment_question.question_assessments.first.position || 0
        end
        column :creator_id do
          result = store.get(V1::User.table_name, old.assessment_question.creator_id)
          new.updater_id = result
          result
        end
        column :updated_at
        column :created_at

        # Migrate the attachment
        if old.file_upload
          attachment = old.file_upload.transform_attachment_reference(store, logger)
          new.attachment = attachment if attachment
        end

        skip_saving_unless_valid

        store.set(V1::AssessmentQuestion.table_name, old.assessment_question.id, new.acting_as.id)
        store.set(V1::AssessmentScribingQuestion.table_name, old.id, new.id)
      end
    end
  end
end

# Schema
#
# V2:
# create_table "course_assessment_questions", force: :cascade do |t|
#   t.integer  "actable_id"
#   t.string   "actable_type",        :limit=>255, :index=>{:name=>"index_course_assessment_questions_actable", :with=>["actable_id"], :unique=>true}
#   t.integer  "assessment_id",       :null=>false, :index=>{:name=>"fk__course_assessment_questions_assessment_id"}, :foreign_key=>{:references=>"course_assessments", :name=>"fk_course_assessment_questions_assessment_id", :on_update=>:no_action, :on_delete=>:no_action}
#   t.string   "title",               :limit=>255
#   t.text     "description"
#   t.text     "staff_only_comments"
#   t.decimal  "maximum_grade",       :precision=>4, :scale=>1, :null=>false
#   t.integer  "weight",              :null=>false
#   t.integer  "creator_id",          :null=>false, :index=>{:name=>"fk__course_assessment_questions_creator_id"}, :foreign_key=>{:references=>"users", :name=>"fk_course_assessment_questions_creator_id", :on_update=>:no_action, :on_delete=>:no_action}
#   t.integer  "updater_id",          :null=>false, :index=>{:name=>"fk__course_assessment_questions_updater_id"}, :foreign_key=>{:references=>"users", :name=>"fk_course_assessment_questions_updater_id", :on_update=>:no_action, :on_delete=>:no_action}
#   t.datetime "created_at",          :null=>false
#   t.datetime "updated_at",          :null=>false
# end
# create_table "course_assessment_question_scribings", force: :cascade do |t|
# end

# V1
# create_table "question_assessments", :force => true do |t|
#   t.integer  "question_id"
#   t.integer  "assessment_id"
#   t.integer  "position"
#   t.datetime "deleted_at"
#   t.datetime "created_at",    :null => false
#   t.datetime "updated_at",    :null => false
# end
# create_table "assessment_questions", :force => true do |t|
#   t.integer  "as_question_id"
#   t.string   "as_question_type"
#   t.integer  "creator_id"
#   t.integer  "dependent_id"
#   t.string   "title"
#   t.text     "description"
#   t.float    "max_grade"
#   t.integer  "attempt_limit"
#   t.boolean  "file_submission",  :default => false
#   t.text     "staff_comments"
#   t.datetime "deleted_at"
#   t.datetime "created_at",                          :null => false
#   t.datetime "updated_at",                          :null => false
# end
# create_table "assessment_scribing_questions", :force => true do |t|
#   t.datetime "created_at", :null => false
#   t.datetime "updated_at", :null => false
#   t.datetime "deleted_at"
# end
