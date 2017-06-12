module V1
  def_model 'user_courses' do
    belongs_to :user, inverse_of: nil
  end
end
