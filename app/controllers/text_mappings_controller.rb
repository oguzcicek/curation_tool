class TextMappingsController < ApplicationController
  before_action :set_text_mapping, only: [:show, :edit, :update, :destroy, :mark_processed, :mark_unprocessed]
  before_action :load_categories, only: [:new, :edit, :import]
  skip_before_action :verify_authenticity_token, only: [:bulk_update_selected]

  def index
    @query = params[:query]
    @category = params[:category]
    @show_processed = params[:show_processed].present? ? params[:show_processed] == "true" : false
    @sort_by = params[:sort_by] || 'processed'
    @sort_direction = params[:sort_direction] || 'asc'
    
    @text_mappings = TextMapping.all
    
    # İşleme durumuna göre filtreleme
    @text_mappings = @show_processed ? @text_mappings : @text_mappings.unprocessed
    
    # Filter by category if provided
    if @category.present?
      category = Category.find_by(name: @category)
      if category
        @text_mappings = @text_mappings.where(category_id: category.id)
      else
        @text_mappings = @text_mappings.none # Kategorisi bulunamadı
      end
    end
    
    # Filter by search query if provided
    if @query.present?
      @text_mappings = @text_mappings.where(
        "original_text LIKE ? OR corrected_text LIKE ? OR notes LIKE ?", 
        "%#{@query}%", "%#{@query}%", "%#{@query}%"
      )
    end
    
    # Eager load category relationship for displaying names
    @text_mappings = @text_mappings.includes(:category)
    
    # Sıralama
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
    
    # Tüm kategorileri getir
    @categories = Category.order(:name).pluck(:name)
    
    # İşlem durumu istatistikleri
    @total_mappings = TextMapping.count
    @processed_count = TextMapping.processed.count
    @unprocessed_count = TextMapping.unprocessed.count
  end

  def show
  end

  def new
    @text_mapping = TextMapping.new
    @text_mapping.category_id = params[:category_id] if params[:category_id].present?
  end

  def create
    @text_mapping = TextMapping.new(text_mapping_params)

    if @text_mapping.save
      redirect_to text_mappings_path, notice: 'Text mapping was successfully created.'
    else
      load_categories
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @text_mapping.update(text_mapping_params)
      redirect_to text_mappings_path, notice: 'Text mapping was successfully updated.'
    else
      load_categories
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
    
    unless ['mark_processed', 'mark_unprocessed'].include?(process_action)
      redirect_to text_mappings_path, alert: 'Invalid action specified.'
      return
    end
    
    if category_id.blank?
      redirect_to text_mappings_path, alert: 'Please select a category.'
      return
    end
    
    mappings = TextMapping.where(category_id: category_id)
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
    redirect_to text_mappings_path, notice: "#{count} mappings marked as #{action_name}."
  end

  def bulk_update_selected
    mapping_ids = params[:mapping_ids]
    corrected_text = params[:bulk_corrected_text]
    
    if mapping_ids.blank?
      redirect_to text_mappings_path, alert: 'No items selected.'
      return
    end
    
    if corrected_text.blank?
      redirect_to text_mappings_path, alert: 'Please enter a corrected text.'
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
      redirect_to text_mappings_path, alert: "Updated #{count} mappings. Errors: #{errors.join(', ')}"
    else
      redirect_to text_mappings_path, notice: "Successfully updated #{count} mappings to '#{corrected_text}'."
    end
  end

  def process_import
    category_name = params[:category]
    file = params[:file]
    
    if file.blank?
      redirect_to import_text_mappings_path, alert: 'Please select a file to import'
      return
    end
    
    if category_name.blank?
      redirect_to import_text_mappings_path, alert: 'Please select a category'
      return
    end
    
    # Önce kategoriyi bul veya oluştur
    if params[:category_type] == 'new'
      # Yeni kategori oluştur
      category = Category.find_or_create_by(name: category_name.strip.downcase) do |cat|
        cat.description = "Category created during import on #{Time.current.strftime('%Y-%m-%d')}"
      end
    else
      # Mevcut kategoriyi bul
      category = Category.find_by(name: category_name)
    end
    
    unless category
      redirect_to import_text_mappings_path, alert: "Could not find or create category: #{category_name}"
      return
    end
    
    # Count for successful and failed imports
    success_count = 0
    failed_count = 0
    error_messages = []
    
    # Process CSV file
    require 'csv'
    begin
      CSV.foreach(file.path, headers: true) do |row|
        original = row['original_text']&.strip
        corrected = row['corrected_text']&.strip
        
        next if original.blank? || corrected.blank?
        
        mapping = TextMapping.find_or_initialize_by(
          original_text: original,
          category_id: category.id
        )
        
        mapping.corrected_text = corrected
        mapping.notes = row['notes']
        # Yeni import edilen eşleşmeler henüz işlenmedi
        mapping.processed = false
        mapping.processed_at = nil
        
        if mapping.save
          success_count += 1
        else
          failed_count += 1
          error_messages << "#{original}: #{mapping.errors.full_messages.join(', ')}"
        end
      end
      
      redirect_to text_mappings_path, notice: "Import completed: #{success_count} mappings imported successfully, #{failed_count} failed."
    rescue => e
      redirect_to import_text_mappings_path, alert: "Error importing file: #{e.message}"
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
    params.require(:text_mapping).permit(:original_text, :corrected_text, :category_id, :notes, :processed)
  end
end
