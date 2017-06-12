module V1
  def_model 'seen_by_users' do
    belongs_to :obj, polymorphic: true, inverse_of: nil
    belongs_to :user_course, inverse_of: nil

    scope :within_courses, ->(course_ids) do
      joins(assessment_answer: :std_course)
    end
  end
end

# create_table "seen_by_users", :force => true do |t|
#   t.integer  "user_course_id"
#   t.integer  "obj_id"
#   t.string   "obj_type"
#   t.datetime "created_at",     :null => false
#   t.datetime "updated_at",     :null => false
# end

# Possible `obj_type`s:
# "Announcement",
# "Assessment",
# "Assessment::Submission",
# "Comic",
# "ForumPost",
# "ForumTopic",
# "Notification",
# "Training",
# "TrainingSubmission",
# "Material",
# "Mission",
# "Submission"
