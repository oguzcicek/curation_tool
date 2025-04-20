class Category < ApplicationRecord

   self.table_name = "mapping_categories"

  has_many :text_mappings, dependent: :nullify

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  
  before_save :normalize_name
  
  def normalize_name
    self.name = name.strip.downcase if name.present?
  end
end
