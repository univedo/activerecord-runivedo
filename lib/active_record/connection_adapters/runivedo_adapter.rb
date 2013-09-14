require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/statement_pool'
require 'arel/visitors/bind_visitor'

require 'runivedo'

module ActiveRecord
  module ConnectionHandling # :nodoc:
    def runivedo_connection(config)
      raise ArgumentError, "No univedo url specified. Missing argument: url" unless config[:url]
      raise ArgumentError, "No univedo app specified. Missing argument: app" unless config[:app]

      session = Runivedo::Connection.new(config[:url], 0x2610 => "marvin")
      session.set_perspective(config[:uts]) if config[:uts]
      perspective = session.get_perspective(config[:app])
      ConnectionAdapters::RunivedoAdapter.new(perspective, logger, config)
    end
  end

  module ConnectionAdapters #:nodoc:
    class RunivedoAdapter < AbstractAdapter
      class Version
        include Comparable

        def initialize(version_string)
          @version = version_string.split('.').map { |v| v.to_i }
        end

        def <=>(version_string)
          @version <=> version_string.split('.').map { |v| v.to_i }
        end
      end

      class BindSubstitution < Arel::Visitors::SQLite # :nodoc:
        include Arel::Visitors::BindVisitor
      end

      def initialize(perspective, logger, config)
        super(perspective.query, logger)

        @active     = nil
        @config = config
        @perspective = perspective

        if self.class.type_cast_config_to_boolean(config.fetch(:prepared_statements) { true })
          @visitor = Arel::Visitors::SQLite.new self
        else
          @visitor = unprepared_visitor
        end
      end

      def adapter_name #:nodoc:
        'Runivedo'
      end

      def active?
        @active != false
      end

      # Disconnects from the database if already connected. Otherwise, this
      # method does nothing.
      def disconnect!
        super
        @active = false
        @connection.close rescue nil
      end

      def native_database_types #:nodoc:
        {
          :primary_key => default_primary_key_type,
          :string      => { :name => "varchar", :limit => 255 },
          :text        => { :name => "text" },
          :integer     => { :name => "integer" },
          :float       => { :name => "float" },
          :decimal     => { :name => "decimal" },
          :datetime    => { :name => "datetime" },
          :timestamp   => { :name => "datetime" },
          :time        => { :name => "time" },
          :date        => { :name => "date" },
          :binary      => { :name => "blob" },
          :boolean     => { :name => "boolean" }
        }
      end

      # DATABASE STATEMENTS ======================================

      def exec_query(sql, name = nil, binds = [])
        p "exec_query"
        p binds
        log(sql, name, binds) do
          stmt    = @connection.prepare(sql)
          cols    = stmt.get_column_names
          i = -1
          binds_hash = Hash[binds.map { |col, val|
            [i += 1, bind[1]]
          }]
          p binds_hash
          records = stmt.execute(binds_hash).to_a
          # stmt.close
          ActiveRecord::Result.new(cols, records)
        end
      end

      def exec_delete(sql, name = 'SQL', binds = [])
        exec_query(sql, name, binds)
        @connection.changes
      end
      alias :exec_update :exec_delete

      def last_inserted_id(result)
        @connection.last_insert_row_id
      end

      def execute(sql, name = nil) #:nodoc:
        log(sql, name) do
          @connection.prepare(sql).execute.to_a
        end
      end

      def update_sql(sql, name = nil) #:nodoc:
        super
        @connection.changes
      end

      def delete_sql(sql, name = nil) #:nodoc:
        sql += " WHERE 1=1" unless sql =~ /WHERE/i
        super sql, name
      end

      def insert_sql(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil) #:nodoc:
        super
        id_value || @connection.last_insert_row_id
      end
      alias :create :insert_sql

      def select_rows(sql, name = nil)
        exec_query(sql, name).rows
      end

      # SCHEMA STATEMENTS ========================================

      def tables(name = nil, table_name = nil) #:nodoc:
        @perspective.get_tables.each_key.to_a
      end

      def primary_key(table_name)
        "#id"
      end

      def columns(table_name)
        @perspective.get_tables[table_name].get_fields.map do |name, field|
          Column.new(name, nil, field.get_sql_datatype)
        end
      end

      protected

      def select(sql, name = nil, binds = []) #:nodoc:
        exec_query(sql, name, binds)
      end
    end
  end
end
