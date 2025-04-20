module Api
  module V1
    class TextMappingsController < ApplicationController
      skip_before_action :verify_authenticity_token, only: [:correct_text]
      
      # GET /api/v1/text_mappings.json
      def index
        @text_mappings = if params[:category].present?
                        TextMapping.by_category(params[:category])
                      else
                        TextMapping.all
                      end
        
        render json: @text_mappings
      end
      
      # POST /api/v1/text_mappings/correct_text
      # Accepts: 
      # {
      #   "texts": ["Land-Rov", "series-bmw-3"],
      #   "category": "make" (optional)
      # }
      def correct_text
        texts = params[:texts]
        category = params[:category]
        
        if texts.blank?
          render json: { error: "No texts provided for correction" }, status: :bad_request
          return
        end
        
        result = {}
        
        texts.each do |text|
          text = text.to_s.strip
          
          # Skip empty texts
          next if text.blank?
          
          query = TextMapping.where(original_text: text)
          query = query.by_category(category) if category.present?
          
          mapping = query.first
          
          if mapping
            result[text] = mapping.corrected_text
          else
            # If no mapping found, return the original text
            result[text] = text
          end
        end
        
        render json: { corrections: result }
      end
    end
  end
end 