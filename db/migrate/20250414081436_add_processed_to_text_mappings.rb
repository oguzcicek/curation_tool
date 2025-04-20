class AddProcessedToTextMappings < ActiveRecord::Migration[8.0]
  def change
    add_column :text_mappings, :processed, :boolean, default: false
    add_column :text_mappings, :processed_at, :datetime
    
    # İşlem durumuna göre filtreleme için indeks
    add_index :text_mappings, :processed
  end
end
