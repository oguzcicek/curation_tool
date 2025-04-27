class TextMappingsController < ApplicationController
  before_action :set_text_mapping, only: [:show, :edit, :update, :destroy, :mark_processed, :mark_unprocessed, :set_as_canonical, :add_to_canonical, :find_canonical_candidates, :show_aliases, :toggle_hidden]
  before_action :load_categories, only: [:new, :edit, :import]
  skip_before_action :verify_authenticity_token, only: [:bulk_update_selected, :create_canonical_relationship]

  def index
    @query = params[:query]
    @category = params[:category]
    @show_processed = params[:show_processed].present? ? params[:show_processed] == "true" : false
    @sort_by = params[:sort_by] || 'processed'
    @sort_direction = params[:sort_direction] || 'asc'
    @show_canonicals = params[:show_canonicals].present? ? params[:show_canonicals] == "true" : false
    
    @text_mappings = TextMapping.all
    
    # filter by processed or unprocessed
    @text_mappings = @show_processed ? @text_mappings : @text_mappings.unprocessed
    
    # Filter by canonical status if requested
    @text_mappings = @text_mappings.canonicals if @show_canonicals
    
    # Filter by category if provided
    if @category.present?
      category = Category.find_by(name: @category)
      if category
        @text_mappings = @text_mappings.where(category_id: category.id)
        
        # Optimize parent mappings query for model group
        # Only fetch parent mappings when necessary and in a more optimized way
        if category.id == 2  # Model group (assuming id:2 is "model group" as specified)
          # Use the already filtered text_mappings to extract unique parent_ids
          # This should be more efficient than querying all text mappings again
          parent_ids = @text_mappings.limit(1000).pluck(:parent_id).compact.uniq
          
          if parent_ids.any?
            # Only fetch the necessary parent mappings
            parent_mappings = TextMapping.where(id: parent_ids).includes(:category)
            @parent_mappings = parent_mappings.index_by(&:id)
          end
        end
      else
        @text_mappings = @text_mappings.none # category not found
      end
    end
    
    # Filter by search query if provided
    if @query.present?
      @text_mappings = @text_mappings.where(
        "curated_mappings.original_text LIKE ? OR curated_mappings.corrected_text LIKE ? OR curated_mappings.notes LIKE ?", 
        "%#{@query}%", "%#{@query}%", "%#{@query}%"
      )
    end
    
    # Eager load category relationship for displaying names
    @text_mappings = @text_mappings.includes(:category)
    
    # Eager load canonical relationship for displaying names
    @text_mappings = @text_mappings.includes(:canonical)
    
    # Sorting
    category_table = Category.table_name
    
    case @sort_by
    when 'processed'
      @text_mappings = @text_mappings.order(processed: @sort_direction, "#{category_table}.name" => :asc, original_text: :asc)
    when 'category'
      @text_mappings = @text_mappings.order("#{category_table}.name" => @sort_direction, processed: :asc, original_text: :asc)
    when 'original_text'
      @text_mappings = @text_mappings.order(original_text: @sort_direction, processed: :asc, "#{category_table}.name" => :asc)
    when 'corrected_text'
      @text_mappings = @text_mappings.order(corrected_text: @sort_direction, processed: :asc, "#{category_table}.name" => :asc)
    when 'processed_at'
      @text_mappings = @text_mappings.order(updated_at: @sort_direction, processed: :asc, "#{category_table}.name" => :asc)
    end
    
    # Eager load parent associations to prevent N+1 queries
    @text_mappings = @text_mappings.includes(:parent) if @category.present? && Category.find_by(name: @category)&.id == 2
    
    # Get all categories
    @categories = Category.order(:name).pluck(:name)
    
    # Process status statistics with caching
    @total_mappings = Rails.cache.fetch("text_mappings_total_count", expires_in: 1.hour) do
      TextMapping.count
    end
    
    @processed_count = Rails.cache.fetch("text_mappings_processed_count", expires_in: 1.hour) do
      TextMapping.processed.count
    end
    
    @unprocessed_count = Rails.cache.fetch("text_mappings_unprocessed_count", expires_in: 1.hour) do
      TextMapping.unprocessed.count
    end
    
    # Add pagination to improve performance with large datasets
    @page = params[:page] || 1
    @per_page = params[:per_page] || 50
    @text_mappings = @text_mappings.page(@page).per(@per_page)
  end

  def show
    # If it has a parent, load it
    @parent = @text_mapping.parent if @text_mapping.parent_id
    
    # Get children mappings if any
    @children = @text_mapping.children
    
    # Get canonical record if this is an alias
    @canonical = @text_mapping.canonical if @text_mapping.canonical_id && @text_mapping.canonical_id != @text_mapping.id
    
    # Get aliases if this is a canonical record
    @aliases = @text_mapping.aliases if @text_mapping.canonical?
  end

  def new
    @text_mapping = TextMapping.new
    @text_mapping.category_id = params[:category_id] if params[:category_id].present?
    @text_mapping.parent_id = params[:parent_id] if params[:parent_id].present?
    
    # Load potential parent mappings for dropdown
    @parent_mappings = TextMapping.all
    if @text_mapping.category_id == 2 # If model group
      @parent_mappings = TextMapping.where(category_id: 1).order(:corrected_text) # Only show makes ordered by corrected_text
    end
  end

  def create
    @text_mapping = TextMapping.new(text_mapping_params)

    if @text_mapping.save
      redirect_to text_mappings_path, notice: 'Text mapping was successfully created.'
    else
      load_categories
      # Load potential parent mappings for dropdown
      @parent_mappings = TextMapping.all
      if @text_mapping.category_id == 2 # If model group
        @parent_mappings = TextMapping.where(category_id: 1).order(:corrected_text) # Only show makes ordered by corrected_text
      end
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # Load potential parent mappings for dropdown
    @parent_mappings = TextMapping.all
    if @text_mapping.category_id == 2 # If model group
      @parent_mappings = TextMapping.where(category_id: 1).order(:corrected_text) # Only show makes ordered by corrected_text
    end
  end

  def update
    if @text_mapping.update(text_mapping_params)
      redirect_to text_mappings_path, notice: 'Text mapping was successfully updated.'
    else
      load_categories
      # Load potential parent mappings for dropdown
      @parent_mappings = TextMapping.all
      if @text_mapping.category_id == 2 # If model group
        @parent_mappings = TextMapping.where(category_id: 1).order(:corrected_text) # Only show makes ordered by corrected_text
      end
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @text_mapping.destroy
    redirect_to text_mappings_path, notice: 'Text mapping was successfully deleted.'
  end
  
  def mark_processed
    @text_mapping.mark_as_processed!
    redirect_back fallback_location: text_mappings_path, notice: 'Mapping marked as processed.'
  end
  
  def mark_unprocessed
    @text_mapping.mark_as_unprocessed!
    redirect_back fallback_location: text_mappings_path, notice: 'Mapping marked as unprocessed.'
  end

  def import
    @categories = Category.order(:name)
  end
  
  def bulk_edit
    @category = params[:category]
    
    if @category.blank?
      redirect_to text_mappings_path, alert: 'Please select a category for bulk editing'
      return
    end
    
    category = Category.find_by(name: @category)
    
    if category.nil?
      redirect_to text_mappings_path, alert: "Category '#{@category}' not found"
      return
    end
    
    @text_mappings = TextMapping.where(category_id: category.id).order(:original_text)
    
    if @text_mappings.empty?
      redirect_to text_mappings_path, alert: "No mappings found for category '#{@category}'"
      return
    end
  end
  
  def bulk_update
    @category = params[:category]
    
    if @category.blank?
      redirect_to text_mappings_path, alert: 'Category is required'
      return
    end
    
    category = Category.find_by(name: @category)
    
    if category.nil?
      redirect_to text_mappings_path, alert: "Category '#{@category}' not found"
      return
    end
    
    if params[:text_mappings].blank?
      redirect_to bulk_edit_text_mappings_path(category: @category), alert: 'No mappings provided'
      return
    end
    
    success_count = 0
    error_count = 0
    
    params[:text_mappings].each do |id, mapping_params|
      mapping = TextMapping.find_by(id: id)
      
      next unless mapping
      
      if mapping.update(corrected_text: mapping_params[:corrected_text])
        success_count += 1
      else
        error_count += 1
      end
    end
    
    redirect_to text_mappings_path(category: @category), 
                notice: "Bulk update completed: #{success_count} mappings updated successfully, #{error_count} failed."
  end
  
  def bulk_process
    category_id = params[:category_id]
    process_action = params[:process_action]
    parent_id = params[:parent_id]
    redirect_url = params[:redirect_url]
    
    unless ['mark_processed', 'mark_unprocessed'].include?(process_action)
      redirect_to redirect_url.present? ? redirect_url : text_mappings_path, alert: 'Invalid action specified.'
      return
    end
    
    if category_id.blank?
      redirect_to redirect_url.present? ? redirect_url : text_mappings_path, alert: 'Please select a category.'
      return
    end
    
    # Base query on category
    mappings = TextMapping.where(category_id: category_id)
    
    # Filter by parent_id if provided
    if parent_id.present?
      parent = TextMapping.find_by(id: parent_id)
      if parent && parent.category_id == 1 # Make
        if parent.corrected_text.present?
          # Find all makes with the same corrected_text
          same_make_records = TextMapping.where(category_id: 1, corrected_text: parent.corrected_text)
          make_ids = same_make_records.pluck(:id) + [parent_id]
          
          # Filter model groups associated with these makes
          mappings = mappings.where(parent_id: make_ids)
        else
          # If corrected_text is missing, filter only by parent_id
          mappings = mappings.where(parent_id: parent_id)
        end
      else
        mappings = mappings.where(parent_id: parent_id)
      end
    end
    
    count = 0
    
    mappings.find_each do |mapping|
      if process_action == 'mark_processed'
        mapping.mark_as_processed!
      else
        mapping.mark_as_unprocessed!
      end
      count += 1
    end
    
    action_name = process_action == 'mark_processed' ? 'processed' : 'unprocessed'
    redirect_to redirect_url.present? ? redirect_url : text_mappings_path, notice: "#{count} mappings marked as #{action_name}."
  end

  def bulk_update_selected
    mapping_ids = params[:mapping_ids]
    corrected_text = params[:bulk_corrected_text]
    redirect_url = params[:redirect_url]
    
    if mapping_ids.blank?
      redirect_to redirect_url.present? ? redirect_url : text_mappings_path, alert: 'No items selected.'
      return
    end
    
    if corrected_text.blank?
      redirect_to redirect_url.present? ? redirect_url : text_mappings_path, alert: 'Please enter a corrected text.'
      return
    end
    
    count = 0
    errors = []
    
    # Ensure mapping_ids is an array
    mapping_ids = Array(mapping_ids)
    
    mapping_ids.each do |id|
      mapping = TextMapping.find_by(id: id)
      next unless mapping
      
      begin
        mapping.update!(corrected_text: corrected_text)
        count += 1
      rescue => e
        errors << "Error updating #{mapping.original_text}: #{e.message}"
      end
    end
    
    if errors.any?
      redirect_to redirect_url.present? ? redirect_url : text_mappings_path, 
                  alert: "Updated #{count} mappings. Errors: #{errors.join(', ')}"
    else
      redirect_to redirect_url.present? ? redirect_url : text_mappings_path, 
                  notice: "Successfully updated #{count} mappings to '#{corrected_text}'."
    end
  end

  # Show model groups associated with a make
  def show_children
    @parent_id = params[:parent_id]
    @parent = TextMapping.find_by(id: @parent_id)
    
    unless @parent
      redirect_to text_mappings_path, alert: "Parent mapping not found"
      return
    end
    
    # Make category id:1, Model Group category id:2 
    @make_category = Category.find_by(id: 1) # Make category
    @model_group_category = Category.find_by(id: 2) # Model Group category
    
    # First get model groups directly associated with this make
    @text_mappings = TextMapping.where(parent_id: @parent_id).includes(:category)
    
    # If there is another make with the same corrected_text, and this make has a corrected_text,
    # add the model groups associated with this make
    if @parent.corrected_text.present?
      # Find other makes with the same corrected_text
      same_make_records = TextMapping.where(category_id: 1, corrected_text: @parent.corrected_text)
                                    .where.not(id: @parent_id)
      
      if same_make_records.any?
        # Add model groups associated with other makes
        other_make_ids = same_make_records.pluck(:id)
        other_models = TextMapping.where(parent_id: other_make_ids).includes(:category)
        @text_mappings = @text_mappings.or(other_models)
      end
    end
    
    # Process status statistics
    @processed_count = @text_mappings.where(processed: true).count
    @unprocessed_count = @text_mappings.where(processed: false).count
    @total_mappings = @processed_count + @unprocessed_count
  end

  # Set current record as canonical and remove any canonical_id it might have
  def set_as_canonical
    if @text_mapping.update(canonical_id: nil)
      redirect_to text_mapping_path(@text_mapping), notice: 'Record marked as canonical.'
    else
      redirect_to text_mapping_path(@text_mapping), alert: 'Failed to mark record as canonical.'
    end
  end
  
  # Add current record as an alias to another canonical record
  def add_to_canonical
    canonical_id = params[:canonical_id]
    
    if canonical_id.blank?
      redirect_to text_mapping_path(@text_mapping), alert: 'No canonical record selected.'
      return
    end
    
    canonical_record = TextMapping.find_by(id: canonical_id)
    
    if canonical_record.nil?
      redirect_to text_mapping_path(@text_mapping), alert: 'Selected canonical record not found.'
      return
    end
    
    # Prevent adding a record as alias to another alias
    if canonical_record.alias?
      redirect_to text_mapping_path(@text_mapping), alert: 'Cannot add as alias to another alias record. Please select a canonical record.'
      return
    end
    
    # Check if trying to add itself or in a circular reference
    if @text_mapping.id == canonical_record.id
      redirect_to text_mapping_path(@text_mapping), alert: 'Cannot add record as alias to itself.'
      return
    end
    
    if @text_mapping.update(canonical_id: canonical_id)
      redirect_to text_mapping_path(@text_mapping), notice: "Record added as alias to #{canonical_record.original_text}."
    else
      redirect_to text_mapping_path(@text_mapping), alert: 'Failed to add record as alias.'
    end
  end
  
  # Find potential canonical records for a text mapping
  def find_canonical_candidates
    @text_mapping = TextMapping.find(params[:id])
    @category_id = @text_mapping.category_id
    
    # Find potential canonical records in the same category
    # that are not aliases themselves
    @candidates = TextMapping.where(category_id: @category_id)
                            .where(canonical_id: nil)
                            .where.not(id: @text_mapping.id)
                            .order(:corrected_text)
    
    render :canonical_candidates
  end
  
  # Show all aliases for a canonical record
  def show_aliases
    @canonical = TextMapping.find(params[:id])
    
    unless @canonical.canonical?
      redirect_to text_mapping_path(@canonical), alert: 'This record is not a canonical record.'
      return
    end
    
    @aliases = @canonical.aliases.includes(:category).order(:original_text)
    
    render :aliases
  end
  
  # BULK OPERATIONS FOR CANONICAL RELATIONSHIPS
  
  # Find duplicate records that might be candidates for canonicalization
  def find_duplicates
    @category = params[:category]
    
    if @category.blank?
      redirect_to text_mappings_path, alert: 'Please select a category to find duplicates'
      return
    end
    
    category = Category.find_by(name: @category)
    
    if category.nil?
      redirect_to text_mappings_path, alert: "Category '#{@category}' not found"
      return
    end
    
    # Find records with duplicate corrected_text
    @duplicates = TextMapping.where(category_id: category.id)
                            .where.not(corrected_text: nil)
                            .where.not(corrected_text: '')
                            .select(:corrected_text)
                            .group(:corrected_text)
                            .having('COUNT(*) > 1')
                            .pluck(:corrected_text)
    
    if @duplicates.empty?
      redirect_to text_mappings_path(category: @category), notice: "No duplicates found in '#{@category}' category"
      return
    end
    
    # For each duplicate, get all records
    @duplicate_groups = @duplicates.map do |corrected|
      TextMapping.where(category_id: category.id, corrected_text: corrected)
                .order(:original_text)
    end
    
    render :duplicates
  end
  
  # Set canonical relationships based on duplicates
  def process_duplicates
    corrected_text = params[:corrected_text]
    canonical_id = params[:canonical_id]
    
    if corrected_text.blank? || canonical_id.blank?
      redirect_to text_mappings_path, alert: 'Missing required parameters'
      return
    end
    
    canonical = TextMapping.find_by(id: canonical_id)
    
    if canonical.nil?
      redirect_to text_mappings_path, alert: 'Selected canonical record not found'
      return
    end
    
    # Find all records with the same corrected_text
    duplicates = TextMapping.where(corrected_text: corrected_text)
                          .where.not(id: canonical_id)
    
    count = 0
    
    duplicates.each do |duplicate|
      # Skip if already an alias of another record
      next if duplicate.canonical_id.present? && duplicate.canonical_id != canonical_id
      
      if duplicate.update(canonical_id: canonical_id)
        count += 1
      end
    end
    
    redirect_to text_mappings_path, notice: "#{count} records marked as aliases of #{canonical.original_text}"
  end

  # Create canonical relationship for multiple records
  def create_canonical_relationship
    canonical_id = params[:canonical_id]
    mapping_ids = params[:mapping_ids].to_s.split(',').map(&:to_i)
    
    # Validate parameters
    if canonical_id.blank? || mapping_ids.blank?
      redirect_to text_mappings_path, alert: 'Missing required parameters'
      return
    end
    
    # Find the canonical record
    canonical = TextMapping.find_by(id: canonical_id)
    
    if canonical.nil?
      redirect_to text_mappings_path, alert: 'Selected canonical record not found'
      return
    end
    
    # First make sure the canonical record itself doesn't have a canonical_id (is not an alias)
    canonical.update(canonical_id: nil) if canonical.canonical_id.present?
    
    # Process all other selected records
    success_count = 0
    error_count = 0
    skipped_count = 0
    
    mapping_ids.each do |id|
      # Skip the canonical record itself
      next if id.to_s == canonical_id.to_s
      
      mapping = TextMapping.find_by(id: id)
      next unless mapping
      
      # Skip if already correctly linked
      if mapping.canonical_id == canonical.id
        skipped_count += 1
        next
      end
      
      # Update the mapping to reference the canonical record
      if mapping.update(canonical_id: canonical.id)
        success_count += 1
      else
        error_count += 1
      end
    end
    
    # Redirect with status message
    if error_count > 0
      redirect_to text_mappings_path, alert: "İlişki oluşturma tamamlandı: #{success_count} kayıt başarıyla bağlandı, #{error_count} kayıtta hata, #{skipped_count} kayıt atlandı."
    else
      redirect_to text_mappings_path, notice: "İlişki oluşturma tamamlandı: #{success_count} kayıt başarıyla '#{canonical.original_text}' kaydına bağlandı."
    end
  end

  # Toggle the is_hidden status of a record
  def toggle_hidden
    current_status = @text_mapping.is_hidden
    if @text_mapping.update(is_hidden: !current_status)
      redirect_back fallback_location: text_mappings_path, 
                    notice: "Record #{!current_status ? 'hidden from' : 'made visible in'} the application."
    else
      redirect_back fallback_location: text_mappings_path, 
                    alert: "Failed to update hidden status."
    end
  end

  private
  
  def set_text_mapping
    @text_mapping = TextMapping.find(params[:id])
  end
  
  def load_categories
    @categories = Category.order(:name)
  end

  def text_mapping_params
    params.require(:text_mapping).permit(:category_id, :original_text, :corrected_text, :notes, :parent_id, :is_hidden, :canonical_id)
  end
end
