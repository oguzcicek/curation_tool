module MigrationHelpers
  # Set string limit for MySQL utf8mb4 indexed columns
  # MySQL has a 1000 byte index length limit for utf8mb4 character set
  # A utf8mb4 character can take up to 4 bytes, so 191 characters * 4 bytes + overhead < 1000 bytes
  def safe_string_limit
    191
  end
end

ActiveRecord::Migration.prepend MigrationHelpers

# Monkey patch ActiveRecord to use 191 as the default string limit when a column is going to be indexed
module ActiveRecord
  module ConnectionAdapters
    module SchemaStatements
      alias_method :original_add_index, :add_index
      
      def add_index(table_name, column_name, options = {})
        # If we're adding an index to a string column, make sure it's not too long
        Array(column_name).each do |col|
          next unless col.is_a?(String) || col.is_a?(Symbol)
          
          column_def = columns(table_name).find { |c| c.name.to_s == col.to_s }
          next unless column_def && column_def.type == :string

          # If it's a string column and it's going to be indexed, limit its length
          if !column_def.limit || column_def.limit > 191
            change_column(table_name, col, :string, limit: 191)
          end
        end
        
        original_add_index(table_name, column_name, options)
      end
    end
  end
end 