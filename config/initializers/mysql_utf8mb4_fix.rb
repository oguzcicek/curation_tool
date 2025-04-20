# This file fixes the MySQL index length limitations with utf8mb4 character set
require 'active_record/connection_adapters/abstract_mysql_adapter'

ActiveSupport.on_load(:active_record) do
  module ActiveRecord::ConnectionAdapters
    class Mysql2Adapter < AbstractMysqlAdapter
      def create_table_definition(*args, **options)
        table_definition = super
        # Rails 8.0 changed how charset and collation are set
        options[:charset] = 'utf8mb4' unless options.key?(:charset)
        options[:collation] = 'utf8mb4_unicode_ci' unless options.key?(:collation)
        table_definition
      end
      
      # Override to ensure new tables use utf8mb4
      def create_table(table_name, **options)
        options[:charset] = 'utf8mb4' unless options.key?(:charset)
        options[:collation] = 'utf8mb4_unicode_ci' unless options.key?(:collation)
        super
      end
    end
  end

  # Change the default string column limit
  # Default string limit is 255 chars in MySQL which requires more than 1000 bytes for an index with utf8mb4
  ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter::NATIVE_DATABASE_TYPES[:string][:limit] = 191
end 