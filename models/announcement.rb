module V1
  def_model 'announcements' do
    include SeenByUserConcern
  end

  ::Course::Announcement.class_eval do
    # Ignore attachment callbacks.
    def update_attachment_references
    end

    # Do not send notification
    def send_notification
    end

    # This is handled in migration separately
    def mark_as_read_by_creator
    end
  end
end
