require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/statement_pool'
require 'arel/visitors/bind_visitor'

require 'runivedo'

module ActiveRecord
  module Type
    class UUID < Type::Value
      def type_cast_for_database(value)
        value.to_s
      end
    end
  end

  module ConnectionHandling # :nodoc:
    def runivedo_connection(config)
      raise ArgumentError, "No univedo url specified. Missing argument: server" unless config[:server]
      raise ArgumentError, "No univedo app specified. Missing argument: app" unless config[:app]

      url = config[:server]
      bucket = config[:bucket]
      app = config[:app]
      username = config[:username]
      uts = config[:uts] ? IO.read(config[:uts]) : nil
      ConnectionAdapters::RunivedoAdapter.new(url, bucket, app, uts, username, logger, config)
    end
  end

  module ConnectionAdapters #:nodoc:
    class RunivedoAdapter < AbstractAdapter
      attr_reader :session, :perspective, :url, :bucket

      class BindSubstitution < Arel::Visitors::SQLite # :nodoc:
        include Arel::Visitors::BindVisitor
      end

      def initialize(url, bucket, app, uts, username, logger, config)
        super(nil, logger)

        @url = url
        @bucket = bucket
        @app = app
        @uts = uts
        @username = username
        @result = nil

        type_map.register_type 'uuid', Type::UUID.new

        @visitor = Arel::Visitors::SQLite.new self

        connect
      end

      def adapter_name #:nodoc:
        'Runivedo'
      end

      def active?
        !@session.closed?
      end

      def connect
        @connection = Runivedo::Connection.new(@url)
        @session = @connection.get_session(@bucket, {username: @username})
        @session.apply_uts(@uts) if @uts
        @perspective = session.get_perspective(@app)
        @connection = @perspective.query
      end

      # Disconnects from the database if already connected. Otherwise, this
      # method does nothing.
      def disconnect!
        super
        @session.close rescue nil
      end

      def reconnect!
        super
        disconnect! rescue nil
        connect
      end

      def native_database_types #:nodoc:
        {
          :primary_key => default_primary_key_type,
          :string      => { :name => "varchar" },
          :text        => { :name => "text" },
          :integer     => { :name => "integer" },
          :float       => { :name => "float" },
          :decimal     => { :name => "decimal" },
          :datetime    => { :name => "datetime" },
          :timestamp   => { :name => "datetime" },
          :time        => { :name => "time" },
          :date        => { :name => "date" },
          :binary      => { :name => "blob" },
          :boolean     => { :name => "boolean" },
          :uuid        => { :name => "uuid" },
        }
      end

      # QUOTING ==================================================

      def quote_table_name_for_assignment(table, attr)
        quote_column_name(attr)
      end

      def quote_column_name(name) #:nodoc:
        %Q("#{name.to_s.gsub('"', '""')}")
      end


      # DATABASE STATEMENTS ======================================

      def exec_query(sql, name = nil, binds = [])
        log(sql, name, binds) do
          if without_prepared_statement?(binds)
            binds = []
          end
          stmt    = @connection.prepare(sql)
          cols    = stmt.column_names
          i = -1
          binds_hash = Hash[binds.map { |col, val|
            [i += 1, val]
          }]
          @result.close if @result
          @result = stmt.execute(binds_hash)
          records = @result.to_a
          stmt.close
          ActiveRecord::Result.new(cols, records)
        end
      end

      def exec_delete(sql, name = 'SQL', binds = [])
        exec_query(sql, name, binds)
        @result.num_affected_rows
      end
      alias :exec_update :exec_delete

      def last_inserted_id(result)
        raise "didn't insert anything" unless @result
        @result.last_inserted_id
      end

      def execute(sql, name = nil) #:nodoc:
        log(sql, name) do
          @connection.prepare(sql).execute.to_a
        end
      end

      def update_sql(sql, name = nil) #:nodoc:
        super
        @result.num_affected_rows
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

      def select_rows(sql, name = nil, binds = [])
        exec_query(sql, name, binds).rows
      end

      # SCHEMA STATEMENTS ========================================

      def tables(name = nil, table_name = nil) #:nodoc:
        @perspective.get_tables
      end

      def primary_key(table_name)
        "id"
      end

      def columns(table_name)
        @perspective.get_fields_for_table(table_name).map do |name, sql_type|
          sql_type = "integer" if sql_type == "pk"
          cast_type = lookup_cast_type(sql_type)
          Column.new(name, nil, cast_type, sql_type)
        end
      end

      protected

      def _type_cast(value)
        case value
        when UUIDTools::UUID
          value.to_s
        else
          value
        end
      end
    end
  end
end
