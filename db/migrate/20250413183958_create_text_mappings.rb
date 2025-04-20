class CreateTextMappings < ActiveRecord::Migration[8.0]
  def change
    create_table :text_mappings do |t|
      t.string :original_text
      t.string :corrected_text
      t.integer :category_id
      t.text :notes

      t.timestamps
    end
    
    add_index :text_mappings, [:original_text, :category], unique: true
  end
end
