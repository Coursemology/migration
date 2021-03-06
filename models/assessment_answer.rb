module V1
  def_model 'assessment_answer_gradings'

  def_model 'assessment_answers' do
    belongs_to :assessment_question, foreign_key: 'question_id', inverse_of: nil
    belongs_to :assessment_submission, foreign_key: 'submission_id', inverse_of: nil
    belongs_to :std_course, class_name: 'UserCourse', inverse_of: nil
    belongs_to :as_answer, polymorphic: true, inverse_of: nil
    # In v1 seems only correct answer has gradings
    has_one :assessment_answer_grading, foreign_key: 'answer_id', inverse_of: nil

    # Remarks:
    # In v2: the answers on top must match the submission state (e.g. if the submission is attempting,
    #   the answers on top must all be attempting). All previous answer has the state of `evaluated`
    #   if the assessment is manually graded, and the state of `graded` if the assessment is autograded.
    # Note that for non programming answers, v2 also only have one answer.
    # In v1: for trainings, the correct answers are marked as finalised.
    #   and for missions, there's no multiple answers, only one answer for one question.
    # List of v2 sates:
    # state :attempting
    # state :submitted
    # state :evaluated
    # state :graded
    def transform_workflow_state
      @workflow_state ||= begin
        assessment = assessment_submission.assessment
        if assessment.as_assessment_type == 'Assessment::Training'
          if answers_of_same_question.size > 1 && id != latest_answer.id
            # For trainings, all previous answers should be graded.
            return :graded
          end
        end

        # Code goes here for missions and trainings with only one answer
        case assessment_submission.status
        when 'graded'
          :graded
        when 'submitted'
          :submitted
        else
          :attempting
        end
      end
    end

    def transform_grade
      if transform_workflow_state == :graded
        grade = assessment_answer_grading.try(:grade)
        if grade
          grade
        else
          correct ? assessment_question.max_grade : 0
        end
      end
    end

    def transform_submitted_at
      if transform_workflow_state != :attempting
        updated_at
      else
        nil
      end
    end

    def transform_graded_at
      if transform_workflow_state == :graded
        if assessment_answer_grading
          assessment_answer_grading.created_at
        else
          created_at
        end
      end
    end

    # The latest answer must have the largest creation time
    def transform_created_at
      if id == latest_answer.id || created_at < latest_answer.created_at
        created_at
      else
        latest_answer.created_at - 1.second
      end
    end

    private

    def answers_of_same_question
      @answers ||= self.class.where(question_id: question_id, submission_id: submission_id).
        includes(:assessment_answer_grading).to_a
    end

    # Return the latest answer of this question and submission
    # might be the finalised answer or just the last answer
    def latest_answer
      # TODO: latest answer should be the one finalised with grading...
      @answer ||= begin
        answers = answers_of_same_question.sort_by(&:created_at)
        finalised_answers = answers.select { |a| a.finalised }
        finalised_and_graded = finalised_answers.select { |a| a.assessment_answer_grading.present? }
        finalised_and_graded.last || finalised_answers.last || answers.last
      end
    end
  end

  ::Course::Assessment::Answer.class_eval do
    # Skipping validating of the grade, there are answers which have grades higher than max grade of the question
    # Should preserve the data.
    def validate_grade
    end

    # Make sure that the validation still works if there is no question or submission.
    def validate_consistent_assessment
      return unless question && submission

      errors.add(:question, :consistent_assessment) if question.assessment_id != submission.assessment_id
    end

    def validate_assessment_state
      return unless submission
      errors.add(:submission, :attemptable_state) unless submission.attempting?
    end

    def validate_consistent_grade
      return unless question
      errors.add(:grade, :consistent_grade) if grade.present? && grade > question.maximum_grade
    end
  end
end
