require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/statement_pool'
require 'arel/visitors/bind_visitor'

require 'runivedo'

module ActiveRecord
  module ConnectionHandling # :nodoc:
    def runivedo_connection(config)
      raise ArgumentError, "No univedo url specified. Missing argument: url" unless config[:url]
      raise ArgumentError, "No univedo app specified. Missing argument: app" unless config[:app]

      conn = Runivedo::Connection.new(config[:url])
      perspective = conn.get_perspective(config[:app])

      ConnectionAdapters::RunivedoAdapter.new(conn, perspective, logger, config)
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

      class StatementPool < ConnectionAdapters::StatementPool
        def initialize(connection, max)
          super
          @cache = Hash.new { |h,pid| h[pid] = {} }
        end

        def each(&block); cache.each(&block); end
        def key?(key);    cache.key?(key); end
        def [](key);      cache[key]; end
        def length;       cache.length; end

        def []=(sql, key)
          while @max <= cache.size
            dealloc(cache.shift.last[:stmt])
          end
          cache[sql] = key
        end

        def clear
          cache.values.each do |hash|
            dealloc hash[:stmt]
          end
          cache.clear
        end

        private
        def cache
          @cache[$$]
        end

        def dealloc(stmt)
          stmt.close unless stmt.closed?
        end
      end

      class BindSubstitution < Arel::Visitors::SQLite # :nodoc:
        include Arel::Visitors::BindVisitor
      end

      def initialize(connection, perspective, logger, config)
        super(connection, logger)
        @perspective = perspective

        @active     = nil
        @statements = StatementPool.new(@connection,
                                        self.class.type_cast_config_to_integer(config.fetch(:statement_limit) { 1000 }))
        @config = config

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

      # Clears the prepared statements cache.
      def clear_cache!
        @statements.clear
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
        log(sql, name, binds) do

          # Don't cache statements without bind values
          if binds.empty?
            stmt    = @connection.prepare(sql)
            cols    = stmt.columns
            records = stmt.to_a
            stmt.close
            stmt = records
          else
            cache = @statements[sql] ||= {
              :stmt => @connection.prepare(sql)
            }
            stmt = cache[:stmt]
            cols = cache[:cols] ||= stmt.columns
            stmt.reset!
            stmt.bind_params binds.map { |col, val|
              type_cast(val, col)
            }
          end

          ActiveRecord::Result.new(cols, stmt.to_a)
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
          q = @perspective.query
          q.prepare(sql)
          q.execute
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

      protected
        def select(sql, name = nil, binds = []) #:nodoc:
          exec_query(sql, name, binds)
        end
    end
  end
end
