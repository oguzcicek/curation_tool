class UpdateTextMappingsCategoryRelationship < ActiveRecord::Migration[8.0]
  def change
    # category_id var ama foreign key eklenmiş mi kontrol et
    add_foreign_key :text_mappings, :categories, if_not_exists: true
    
    # category_id null: false kısıtlamasını kaldır, kategorileri migrasyon sırasında eşleştirmek için
    change_column_null :text_mappings, :category_id, true
    
    # Geçici bir migration verileri dönüştürmek için
    reversible do |dir|
      dir.up do
        # Mevcut 'category' sütunundaki değerlere göre category_id değerlerini güncelle
        execute <<-SQL
          UPDATE text_mappings tm 
          LEFT JOIN categories c ON tm.category = c.name
          SET tm.category_id = c.id
          WHERE tm.category_id IS NULL AND c.id IS NOT NULL;
        SQL
      end
    end
  end
end
