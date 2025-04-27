class TextMapping < ApplicationRecord

  # for stage environment
  self.table_name = "curated_mappings"

  # Veritabanındaki mevcut sütunları doğru şekilde tanımla
  attribute :processed_at, :datetime
  attribute :is_hidden, :boolean, default: false

  belongs_to :category, optional: true, counter_cache: true
  belongs_to :parent, class_name: "TextMapping", optional: true
  has_many :children, class_name: "TextMapping", foreign_key: "parent_id"
  
  # Canonical ilişkisi
  belongs_to :canonical, class_name: "TextMapping", optional: true, foreign_key: "canonical_id"
  has_many :aliases, class_name: "TextMapping", foreign_key: "canonical_id"
  
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
  
  # Parent ID'ye göre alt elamanları bulmak için scope
  scope :with_parent, ->(parent_id) { where(parent_id: parent_id) }
  
  # Canonical ilişkisi için scope'lar
  scope :canonicals, -> { where(canonical_id: nil) }
  scope :aliases, -> { where.not(canonical_id: nil) }
  
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
  
  # Get parent mapping for this text mapping
  def parent_mapping
    parent
  end
  
  # Recursive method to get all parent mappings
  def all_parents
    return [] unless parent_id
    result = []
    current = self
    while current.parent_id
      parent = current.parent
      result << parent
      current = parent
    end
    result
  end
  
  # Canonical ilişkisi için metotlar
  
  # Kayıt canonical mi?
  def canonical?
    canonical_id.nil? || canonical_id == id
  end
  
  # Kayıt bir alias mi?
  def alias?
    canonical_id.present? && canonical_id != id
  end
  
  # Canonical kaydı döndür (eğer bu bir alias ise)
  def canonical_record
    canonical
  end
  
  # Bu kaydın alias'larını döndür (eğer bu bir canonical ise)
  def alias_records
    aliases
  end
  
  # Bir kaydı bu kaydın alias'ı olarak işaretle
  def add_alias(text_mapping)
    return false if text_mapping.nil? || id.nil? || id == text_mapping.id
    text_mapping.update(canonical_id: id)
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
