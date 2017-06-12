TYPE_MAPPING = {
  'Assessment' => V1::Assessment.name,
  'Assessment::Training' => V1::AssessmentTraining.name,
  'Assessment::Mission' => V1::AssessmentMission.name,
  'Assessment::McqQuestion' => V1::AssessmentMcqQuestion.name,
  'Assessment::ScribingQuestion' => V1::AssessmentScribingQuestion.name,
  'Assessment::CodingQuestion' => V1::AssessmentCodingQuestion.name,
  'Assessment::GeneralQuestion' => V1::AssessmentGeneralQuestion.name,
  'Assessment::Submission' => V1::AssessmentSubmission.name,
  'Assessment::Answer' => V1::AssessmentAnswer.name,
  'Assessment::McqAnswer' => V1::AssessmentMcqAnswer.name,
  'Assessment::ScribingAnswer' => V1::AssessmentScribingAnswer.name,
  'Assessment::CodingAnswer' => V1::AssessmentCodingAnswer.name,
  'Assessment::GeneralAnswer' => V1::AssessmentGeneralAnswer.name,
  'AsmReq' => V1::AsmReq.name,
  'Announcement' => V1::Announcement.name,
  'Achievement' => V1::Achievement.name,
  'Level' => V1::Level.name,
  'Material' => V1::Material.name
}

module ActiveRecord
  module Associations
    class BelongsToPolymorphicAssociation < BelongsToAssociation #:nodoc:
      def klass
        type = owner[reflection.foreign_type]
        if TYPE_MAPPING[type]
          type = TYPE_MAPPING[type]
        end
        type.presence && type.constantize
      end
    end

    AssociationRelation.class_eval do
      def bind_values_with_type_conversion
        bind_values_without_type_conversion.each do |pair|
          if pair[1] && TYPE_MAPPING.key(pair[1])
            pair[1] = TYPE_MAPPING.key(pair[1])
          end
        end
      end

      alias_method_chain :bind_values, :type_conversion
    end
  end
end

module Arel
  TreeManager.class_eval do
    def bind_values_with_type_conversion
      bind_values_without_type_conversion.each do |pair|
        if pair[1] && TYPE_MAPPING.key(pair[1])
          pair[1] = TYPE_MAPPING.key(pair[1])
        end
      end
    end

    alias_method_chain :bind_values, :type_conversion
  end
end
