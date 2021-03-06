module V1
  def_model 'comment_topics' do
    belongs_to :topic, polymorphic: true, inverse_of: nil
    belongs_to :course, inverse_of: nil

    scope :within_courses, ->(course_ids) do
      # Possible types:
      # "Assessment::Answer", "Assessment::Submission", "Assessment::McqQuestion", "Assessment::CodingQuestion", "Assessment::Question"
      # For `Assessment::Submission` type, only very old assessments have it, I suspect that time answer don't have comments.
      where(topic_type: 'Assessment::Answer').where(course_id: Array(course_ids)).includes(:topic)
    end

    def transform_course_id(store)
      store.get(Course.table_name, course_id)
    end

    def transform_submission_id(store)
      store.get(AssessmentSubmission.table_name, topic.submission_id)
    end

    def transform_question_id(store)
      store.get(AssessmentQuestion.table_name, topic.question_id)
    end
  end
end
