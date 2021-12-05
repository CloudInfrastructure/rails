require "cases/helper"
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

if ActiveRecord::Base.connection.supports_ranges?
  class PostgresqlRange < ActiveRecord::Base
    self.table_name = "postgresql_ranges"
  end

  class PostgresqlRangeTest < ActiveRecord::TestCase
    def teardown
      @connection.execute 'DROP TABLE IF EXISTS postgresql_ranges'
    end

    def setup
      @connection = ActiveRecord::Base.connection
      begin
        @connection.transaction do
          @connection.create_table('postgresql_ranges') do |t|
            t.daterange :date_range
            t.numrange :num_range
            t.tsrange :ts_range
            t.tstzrange :tstz_range
            t.int4range :int4_range
            t.int8range :int8_range
          end
        end
      rescue ActiveRecord::StatementInvalid
        skip "do not test on PG without range"
      end

      insert_range(id: 101,
                   date_range: "[''2012-01-02'', ''2012-01-04'']",
                   num_range: "[0.1, 0.2]",
                   ts_range: "[''2010-01-01 14:30'', ''2011-01-01 14:30'']",
                   tstz_range: "[''2010-01-01 14:30:00+05'', ''2011-01-01 14:30:00-03'']",
                   int4_range: "[1, 10]",
                   int8_range: "[10, 100]")

      insert_range(id: 102,
                   date_range: "(''2012-01-02'', ''2012-01-04'')",
                   num_range: "[0.1, 0.2)",
                   ts_range: "[''2010-01-01 14:30'', ''2011-01-01 14:30'')",
                   tstz_range: "[''2010-01-01 14:30:00+05'', ''2011-01-01 14:30:00-03'')",
                   int4_range: "(1, 10)",
                   int8_range: "(10, 100)")

      insert_range(id: 103,
                   date_range: "(''2012-01-02'',]",
                   num_range: "[0.1,]",
                   ts_range: "[''2010-01-01 14:30'',]",
                   tstz_range: "[''2010-01-01 14:30:00+05'',]",
                   int4_range: "(1,]",
                   int8_range: "(10,]")

      insert_range(id: 104,
                   date_range: "[,]",
                   num_range: "[,]",
                   ts_range: "[,]",
                   tstz_range: "[,]",
                   int4_range: "[,]",
                   int8_range: "[,]")

      insert_range(id: 105,
                   date_range: "(''2012-01-02'', ''2012-01-02'')",
                   num_range: "(0.1, 0.1)",
                   ts_range: "(''2010-01-01 14:30'', ''2010-01-01 14:30'')",
                   tstz_range: "(''2010-01-01 14:30:00+05'', ''2010-01-01 06:30:00-03'')",
                   int4_range: "(1, 1)",
                   int8_range: "(10, 10)")

      @new_range = PostgresqlRange.new
      @first_range = PostgresqlRange.find(101)
      @second_range = PostgresqlRange.find(102)
      @third_range = PostgresqlRange.find(103)
      @fourth_range = PostgresqlRange.find(104)
      @empty_range = PostgresqlRange.find(105)
    end

    def test_data_type_of_range_types
      assert_equal :daterange, @first_range.column_for_attribute(:date_range).type
      assert_equal :numrange, @first_range.column_for_attribute(:num_range).type
      assert_equal :tsrange, @first_range.column_for_attribute(:ts_range).type
      assert_equal :tstzrange, @first_range.column_for_attribute(:tstz_range).type
      assert_equal :int4range, @first_range.column_for_attribute(:int4_range).type
      assert_equal :int8range, @first_range.column_for_attribute(:int8_range).type
    end

    def test_int4range_values
      assert_equal 1...11, @first_range.int4_range
      assert_equal 2...10, @second_range.int4_range
      assert_equal 2...Float::INFINITY, @third_range.int4_range
      assert_equal(-Float::INFINITY...Float::INFINITY, @fourth_range.int4_range)
      assert_nil @empty_range.int4_range
    end

    def test_int8range_values
      assert_equal 10...101, @first_range.int8_range
      assert_equal 11...100, @second_range.int8_range
      assert_equal 11...Float::INFINITY, @third_range.int8_range
      assert_equal(-Float::INFINITY...Float::INFINITY, @fourth_range.int8_range)
      assert_nil @empty_range.int8_range
    end

    def test_daterange_values
      assert_equal Date.new(2012, 1, 2)...Date.new(2012, 1, 5), @first_range.date_range
      assert_equal Date.new(2012, 1, 3)...Date.new(2012, 1, 4), @second_range.date_range
      assert_equal Date.new(2012, 1, 3)...Float::INFINITY, @third_range.date_range
      assert_equal(-Float::INFINITY...Float::INFINITY, @fourth_range.date_range)
      assert_nil @empty_range.date_range
    end

    def test_numrange_values
      assert_equal BigDecimal.new('0.1')..BigDecimal.new('0.2'), @first_range.num_range
      assert_equal BigDecimal.new('0.1')...BigDecimal.new('0.2'), @second_range.num_range
      assert_equal BigDecimal.new('0.1')...BigDecimal.new('Infinity'), @third_range.num_range
      assert_equal BigDecimal.new('-Infinity')...BigDecimal.new('Infinity'), @fourth_range.num_range
      assert_nil @empty_range.num_range
    end

    def test_tsrange_values
      tz = ::ActiveRecord::Base.default_timezone
      assert_equal Time.send(tz, 2010, 1, 1, 14, 30, 0)..Time.send(tz, 2011, 1, 1, 14, 30, 0), @first_range.ts_range
      assert_equal Time.send(tz, 2010, 1, 1, 14, 30, 0)...Time.send(tz, 2011, 1, 1, 14, 30, 0), @second_range.ts_range
      assert_equal(-Float::INFINITY...Float::INFINITY, @fourth_range.ts_range)
      assert_nil @empty_range.ts_range
    end

    def test_tstzrange_values
      assert_equal Time.parse('2010-01-01 09:30:00 UTC')..Time.parse('2011-01-01 17:30:00 UTC'), @first_range.tstz_range
      assert_equal Time.parse('2010-01-01 09:30:00 UTC')...Time.parse('2011-01-01 17:30:00 UTC'), @second_range.tstz_range
      assert_equal(-Float::INFINITY...Float::INFINITY, @fourth_range.tstz_range)
      assert_nil @empty_range.tstz_range
    end

    def test_create_tstzrange
      tstzrange = Time.parse('2010-01-01 14:30:00 +0100')...Time.parse('2011-02-02 14:30:00 CDT')
      round_trip(@new_range, :tstz_range, tstzrange)
      assert_equal @new_range.tstz_range, tstzrange
      assert_equal @new_range.tstz_range, Time.parse('2010-01-01 13:30:00 UTC')...Time.parse('2011-02-02 19:30:00 UTC')
    end

    def test_update_tstzrange
      assert_equal_round_trip(@first_range, :tstz_range,
                              Time.parse('2010-01-01 14:30:00 CDT')...Time.parse('2011-02-02 14:30:00 CET'))
      assert_nil_round_trip(@first_range, :tstz_range,
                            Time.parse('2010-01-01 14:30:00 +0100')...Time.parse('2010-01-01 13:30:00 +0000'))
    end

    def test_create_tsrange
      tz = ::ActiveRecord::Base.default_timezone
      assert_equal_round_trip(@new_range, :ts_range,
                              Time.send(tz, 2010, 1, 1, 14, 30, 0)...Time.send(tz, 2011, 2, 2, 14, 30, 0))
    end

    def test_update_tsrange
      tz = ::ActiveRecord::Base.default_timezone
      assert_equal_round_trip(@first_range, :ts_range,
                              Time.send(tz, 2010, 1, 1, 14, 30, 0)...Time.send(tz, 2011, 2, 2, 14, 30, 0))
      assert_nil_round_trip(@first_range, :ts_range,
                            Time.send(tz, 2010, 1, 1, 14, 30, 0)...Time.send(tz, 2010, 1, 1, 14, 30, 0))
    end

    def test_create_numrange
      assert_equal_round_trip(@new_range, :num_range,
                              BigDecimal.new('0.5')...BigDecimal.new('1'))
    end

    def test_update_numrange
      assert_equal_round_trip(@first_range, :num_range,
                              BigDecimal.new('0.5')...BigDecimal.new('1'))
      assert_nil_round_trip(@first_range, :num_range,
                            BigDecimal.new('0.5')...BigDecimal.new('0.5'))
    end

    def test_create_daterange
      assert_equal_round_trip(@new_range, :date_range,
                              Range.new(Date.new(2012, 1, 1), Date.new(2013, 1, 1), true))
    end

    def test_update_daterange
      assert_equal_round_trip(@first_range, :date_range,
                              Date.new(2012, 2, 3)...Date.new(2012, 2, 10))
      assert_nil_round_trip(@first_range, :date_range,
                            Date.new(2012, 2, 3)...Date.new(2012, 2, 3))
    end

    def test_create_int4range
      assert_equal_round_trip(@new_range, :int4_range, Range.new(3, 50, true))
    end

    def test_update_int4range
      assert_equal_round_trip(@first_range, :int4_range, 6...10)
      assert_nil_round_trip(@first_range, :int4_range, 3...3)
    end

    def test_create_int8range
      assert_equal_round_trip(@new_range, :int8_range, Range.new(30, 50, true))
    end

    def test_update_int8range
      assert_equal_round_trip(@first_range, :int8_range, 60000...10000000)
      assert_nil_round_trip(@first_range, :int8_range, 39999...39999)
    end

    private
      def assert_equal_round_trip(range, attribute, value)
        round_trip(range, attribute, value)
        assert_equal value, range.public_send(attribute)
      end

      def assert_nil_round_trip(range, attribute, value)
        round_trip(range, attribute, value)
        assert_nil range.public_send(attribute)
      end

      def round_trip(range, attribute, value)
        range.public_send "#{attribute}=", value
        assert range.save
        assert range.reload
      end

      def insert_range(values)
        @connection.execute <<-SQL
          INSERT INTO postgresql_ranges (
            id,
            date_range,
            num_range,
            ts_range,
            tstz_range,
            int4_range,
            int8_range
          ) VALUES (
            #{values[:id]},
            '#{values[:date_range]}',
            '#{values[:num_range]}',
            '#{values[:ts_range]}',
            '#{values[:tstz_range]}',
            '#{values[:int4_range]}',
            '#{values[:int8_range]}'
          )
        SQL
      end
  end
end
