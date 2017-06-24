class AssessmentTrqKeywordSolutionTable < BaseTable
  table_name 'assessment_auto_grading_keyword_options'
  scope { |ids| within_courses(ids) }

  def migrate_batch(batch)
    batch.each do |old|
      new = ::Course::Assessment::Question::TextResponseSolution.new
      
      migrate(old, new) do
        column :question_id do
          store.get(V1::AssessmentGeneralQuestion.table_name, old.general_question_id)
        end
        column :solution_type do
          # [:exact_match, :keyword]
          :keyword
        end
        column :keyword => :solution
        column :grade do
          grade = old.score
          if grade >= 1000
            logger.log("Invalid #{old.class} #{old.id}: grade greate than 1000, set to 999.9")
            grade = 999.9
          end
          grade
        end

        skip_saving_unless_valid
        
        store.set(model.table_name, old.id, new.id)
      end
    end
  end
end

class AssessmentTrqExactMatchSolutionTable < BaseTable
  table_name 'assessment_auto_grading_exact_options'
  scope { |ids| within_courses(ids) }

  def migrate_batch(batch)
    batch.each do |old|
      new = ::Course::Assessment::Question::TextResponseSolution.new

      migrate(old, new) do
        column :question_id do
          store.get(V1::AssessmentGeneralQuestion.table_name, old.general_question_id)
        end
        column :solution_type do
          # [:exact_match, :keyword]
          :exact_match
        end
        column :answer => :solution
        column :grade do
          if old.correct
            # V1 don't have grade for each option, give the max grade of the question
            Course::Assessment::Question::TextResponse.find(new.question_id).maximum_grade
          else
            0 # Set grade to zero for those not correct solutions
          end
        end
        column :explanation

        skip_saving_unless_valid

        store.set(model.table_name, old.id, new.id)
      end
    end
  end
end

# Schema
#
# V2:
# create_table "course_assessment_question_text_response_solutions", force: :cascade do |t|
#   t.integer "question_id",   :null=>false, :index=>{:name=>"fk__course_assessment_text_response_solution_question"}, :foreign_key=>{:references=>"course_assessment_question_text_responses", :name=>"fk_course_assessment_questi_2fbeabfad04f21c2d05c8b2d9100d1c4", :on_update=>:no_action, :on_delete=>:no_action}
#   t.integer "solution_type", :default=>0, :null=>false
#   t.text    "solution",      :null=>false
#   t.decimal "grade",         :precision=>4, :scale=>1, :default=>0.0, :null=>false
#   t.text    "explanation"
# end

# V1
# create_table "assessment_auto_grading_exact_options", :force => true do |t|
#   t.integer "general_question_id"
#   t.boolean "correct"
#   t.text    "answer"
#   t.text    "explanation"
# end
#
# create_table "assessment_auto_grading_keyword_options", :force => true do |t|
#   t.integer "general_question_id"
#   t.string  "keyword"
#   t.integer "score"
# end
