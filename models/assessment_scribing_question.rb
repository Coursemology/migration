module V1
  def_model 'assessment_scribing_questions' do
    has_one :assessment_question, as: :as_question, inverse_of: nil
    has_one :file_upload, as: :owner, inverse_of: nil


    scope :within_courses, ->(course_ids) do
      joins(assessment_question: :assessments).
        where(
          {
            assessment_question: {
              assessments: {
                course_id: Array(course_ids)
              }
            }
          }
        )
    end
  end
end