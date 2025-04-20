class TextMapping < ApplicationRecord

  # for stage environment
  self.table_name = "curated_mappings"

  belongs_to :category, optional: true
  
  validates :original_text, presence: true
  validates :corrected_text, presence: true, if: :processed?
  validates :category_id, presence: true
  validates :original_text, uniqueness: { scope: :category_id, message: "already has a mapping in this category" }
  
  scope :by_category, ->(category_name) { 
    joins(:category).where("categories.name = ?", category_name)
  }
  
  # İşlenme durumuna göre scope'lar
  scope :processed, -> { where(processed: true) }
  scope :unprocessed, -> { where(processed: false) }
  
  # Sıralama için scope
  scope :prioritized, -> { order(processed: :asc, processed_at: :desc, created_at: :desc) }
  
  before_save :normalize_texts, :check_processed_status
  
  # İşleme durumunu güncellemek için metotlar
  def mark_as_processed!
    update!(processed: true, processed_at: Time.current)
  end
  
  def mark_as_unprocessed!
    update!(processed: false, processed_at: nil)
  end
  
  def processed?
    processed
  end
  
  def category_name
    category.try(:name)
  end
  
  private
  
  def normalize_texts
    self.original_text = original_text.strip if original_text.present?
    self.corrected_text = corrected_text.strip if corrected_text.present?
  end
  
  def check_processed_status
    if corrected_text_changed? && corrected_text.present?
      self.processed = true
      self.processed_at = Time.current
    end
  end
end
