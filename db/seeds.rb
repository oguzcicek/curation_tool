categories = {
  make: "Car manufacturer names",
  model: "Car model names",
  model_group: "Car model groupings",
  feature: "Car features and options"
}

# Kategorileri oluştur
categories.each do |name, description|
  Category.find_or_create_by!(name: name.to_s) do |category|
    category.description = description
  end
end

puts "Created #{Category.count} categories"

# Kategorilerin ID'lerini alma
make_id = Category.find_by(name: "make")&.id
model_id = Category.find_by(name: "model")&.id
model_group_id = Category.find_by(name: "model_group")&.id
feature_id = Category.find_by(name: "feature")&.id

# Text eşleştirmeleri - [original_text, corrected_text, category_id, notes, processed]
text_mappings = [
  # Car makes - Some processed, some not
  ['Land-Rover', 'Land Rover', make_id, '', true],
  ['Land-Rov', '', make_id, '', false],
  ['Land-R', '', make_id, '', false],
  ['B-M-W', 'BMW', make_id, '', true],
  ['Bmw', 'BMW', make_id, '', true],
  ['Mercedes', '', make_id, '', false],
  ['Merc', '', make_id, '', false],
  ['MB', '', make_id, '', false],
  ['Audi', '', make_id, '', false],
  ['AUDI', '', make_id, '', false],
  ['Volkswagen', '', make_id, '', false],
  ['VW', '', make_id, '', false],
  ['Volvo', '', make_id, '', false],
  ['VOLVO', '', make_id, '', false],
  
  # Car models - All processed
  ['bmw-3-series', 'BMW 3', model_id, '', true],
  ['series-bmw-3', 'BMW 3', model_id, '', true],
  ['bmw-3', 'BMW 3', model_id, '', true],
  ['rav4', 'RAV4', model_id, '', true],
  ['rav-4', 'RAV4', model_id, '', true],
  
  # Model groups - None processed
  ['luxury', '', model_group_id, '', false],
  ['lux', '', model_group_id, '', false],
  ['premium', '', model_group_id, '', false],
  
  # Features - Some processed
  ['bluetooth', 'Bluetooth', feature_id, '', true],
  ['blue-tooth', '', feature_id, '', false],
  ['bt', '', feature_id, '', false],
  ['navigation', 'GPS Navigation', feature_id, '', true],
  ['nav', '', feature_id, '', false],
  ['nav-sys', '', feature_id, '', false]
]

# İşleme zamanı için tarih aralığı - son 30 gün içerisinde rastgele
thirty_days_ago = 30.days.ago
now = Time.current

text_mappings.each do |original, corrected, category_id, notes, processed|
  next unless category_id # Kategori ID'si bulunamazsa atla
  
  # İşlenmiş olanlar için rastgele bir tarih atanır
  processed_at = processed ? rand(thirty_days_ago..now) : nil
  
  # Önce mevcut kaydı bul veya yeni oluştur
  mapping = TextMapping.find_or_initialize_by(
    original_text: original,
    category_id: category_id
  )
  
  # Kaydı güncelle
  mapping.update!(
    corrected_text: corrected,
    notes: notes,
    processed: processed,
    processed_at: processed_at
  )
end

puts "Created #{TextMapping.count} text mappings"
puts "Processed: #{TextMapping.where(processed: true).count}"
puts "Unprocessed: #{TextMapping.where(processed: false).count}"
