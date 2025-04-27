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
        
        # Filter by canonical status if requested
        if params[:only_canonicals].present? && params[:only_canonicals] == 'true'
          @text_mappings = @text_mappings.canonicals
        end
        
        # If include_parents param is set, include parent relationships
        if params[:include_parents].present? && params[:include_parents] == 'true'
          parent_ids = @text_mappings.where.not(parent_id: nil).pluck(:parent_id).uniq
          parents = TextMapping.where(id: parent_ids)
          
          # Include parent mappings in response
          render json: {
            text_mappings: @text_mappings.as_json(include: :category, methods: [:category_name]),
            parents: parents.as_json(include: :category, methods: [:category_name])
          }
        # If include_canonicals param is set, include canonical relationships
        elsif params[:include_canonicals].present? && params[:include_canonicals] == 'true'
          canonical_ids = @text_mappings.where.not(canonical_id: nil).pluck(:canonical_id).uniq
          canonicals = TextMapping.where(id: canonical_ids)
          
          # Include canonical mappings in response
          render json: {
            text_mappings: @text_mappings.as_json(include: [:category, :canonical], 
                                               methods: [:category_name, :canonical?]),
            canonicals: canonicals.as_json(include: :category, methods: [:category_name])
          }
        else
          render json: @text_mappings.as_json(include: [:category, :canonical], 
                                           methods: [:category_name, :canonical?])
        end
      end
      
      # GET /api/v1/text_mappings/hierarchical.json
      # Returns text mappings in a hierarchical structure
      def hierarchical
        category_name = params[:category]
        
        if category_name.present?
          category = Category.find_by(name: category_name)
          
          if category
            # For model groups, include their parent makes
            if category.id == 2 # Model Group
              # Get all model groups
              model_groups = TextMapping.where(category_id: 2)
              
              # Group them by parent_id
              grouped_models = model_groups.group_by(&:parent_id)
              
              # Get all makes that have model groups
              parent_ids = model_groups.pluck(:parent_id).compact.uniq
              makes = TextMapping.where(id: parent_ids)
              
              # Build hierarchical response
              result = makes.map do |make|
                make_data = make.as_json(include: :category, methods: [:category_name])
                make_data[:children] = grouped_models[make.id]&.map { |model| model.as_json(include: :category, methods: [:category_name]) } || []
                make_data
              end
              
              render json: result
            else
              # For other categories, just return flat list
              render json: TextMapping.where(category_id: category.id).as_json(include: :category, methods: [:category_name])
            end
          else
            render json: { error: "Category not found" }, status: :not_found
          end
        else
          render json: { error: "Category parameter is required" }, status: :bad_request
        end
      end
      
      # GET /api/v1/text_mappings/canonicals.json
      # Returns all canonical records and their aliases
      def canonicals
        category_name = params[:category]
        
        if category_name.present?
          category = Category.find_by(name: category_name)
          
          if category
            # Get all canonical records in this category
            canonicals = TextMapping.where(category_id: category.id, canonical_id: nil)
            
            # For each canonical, include its aliases
            result = canonicals.map do |canonical|
              canonical_data = canonical.as_json(include: :category, methods: [:category_name])
              canonical_data[:aliases] = canonical.aliases
                                                 .order(:original_text)
                                                 .as_json(include: :category, methods: [:category_name])
              canonical_data
            end
            
            render json: result
          else
            render json: { error: "Category not found" }, status: :not_found
          end
        else
          render json: { error: "Category parameter is required" }, status: :bad_request
        end
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
        include_parent = params[:include_parent].present? && params[:include_parent] == 'true'
        include_canonical = params[:include_canonical].present? && params[:include_canonical] == 'true'
        
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
            correction = mapping.corrected_text
            response_data = { corrected_text: correction }
            
            # Check if mapping is an alias
            if mapping.alias? && mapping.canonical.present?
              canonical = mapping.canonical
              response_data[:canonical] = {
                id: canonical.id,
                original_text: canonical.original_text,
                corrected_text: canonical.corrected_text
              }
              
              # If canonical record has a different corrected_text, use it instead
              response_data[:corrected_text] = canonical.corrected_text if canonical.corrected_text.present?
            end
            
            # If include_parent is true and this is a model group, include its parent make
            if include_parent && mapping.category_id == 2 && mapping.parent_id.present? 
              parent = mapping.parent
              if parent
                response_data[:parent] = {
                  id: parent.id,
                  original_text: parent.original_text,
                  corrected_text: parent.corrected_text,
                  category_id: parent.category_id,
                  category_name: parent.category_name
                }
              end
            end
            
            # Return full response data if any relations are requested
            if include_parent || include_canonical
              result[text] = response_data
            else
              result[text] = correction
            end
          else
            # If no mapping found, return the original text
            result[text] = include_parent || include_canonical ? { corrected_text: text } : text
          end
        end
        
        render json: { corrections: result }
      end
    end
  end
end 