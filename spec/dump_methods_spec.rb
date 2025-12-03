require 'spec_helper'

describe SeedDump do

  # Helper for expected output based on default factory values (integer: 42)
  # Uses ISO 8601 format with timezone suffix (issue #111)
  def expected_output(include_id = false, id_offset = 0, count = 3)
      output = "Sample.create!([\n  "
      data = []
      start_id = 1 + id_offset
      end_id = count + id_offset # Adjust end based on count
      (start_id..end_id).each do |i|
        # Expect integer: 42, ISO 8601 format with timezone
        data << "{#{include_id ? "id: #{i}, " : ''}string: \"string\", text: \"text\", integer: 42, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04T19:14:00Z\", time: \"2000-01-01T03:15:00Z\", date: \"1863-11-19\", binary: \"binary\", boolean: false}"
      end
      output + data.join(",\n  ") + "\n])\n"
  end

  # Helper for activerecord-import output based on default factory values
  # Uses ISO 8601 format with timezone suffix (issue #111)
  def expected_import_output(exclude_id_timestamps = true)
    columns = if exclude_id_timestamps
                [:string, :text, :integer, :float, :decimal, :datetime, :time, :date, :binary, :boolean]
              else
                [:id, :string, :text, :integer, :float, :decimal, :datetime, :time, :date, :binary, :boolean, :created_at, :updated_at]
              end
    output = "Sample.import([#{columns.map(&:inspect).join(', ')}], [\n  "
    data = []
    (1..3).each do |i|
       row = if exclude_id_timestamps
               # Expect integer: 42, ISO 8601 format with timezone
               ["string", "text", 42, 3.14, "2.72", "1776-07-04T19:14:00Z", "2000-01-01T03:15:00Z", "1863-11-19", "binary", false]
             else
               # Expect integer: 42, ISO 8601 format with timezone
               [i, "string", "text", 42, 3.14, "2.72", "1776-07-04T19:14:00Z", "2000-01-01T03:15:00Z", "1863-11-19", "binary", false, "1969-07-20T20:18:00Z", "1989-11-10T04:20:00Z"]
             end
       data << "[#{row.map(&:inspect).join(', ')}]"
    end
    output + data.join(",\n  ") + "\n])\n"
  end

  # Helper for activerecord-import output with options
  # Uses ISO 8601 format with timezone suffix (issue #111)
  def expected_import_output_with_options
    columns = [:id, :string, :text, :integer, :float, :decimal, :datetime, :time, :date, :binary, :boolean, :created_at, :updated_at]
    output = "Sample.import([#{columns.map(&:inspect).join(', ')}], [\n  "
    data = []
    (1..3).each do |i|
       # Expect integer: 42, ISO 8601 format with timezone
       row = [i, "string", "text", 42, 3.14, "2.72", "1776-07-04T19:14:00Z", "2000-01-01T03:15:00Z", "1863-11-19", "binary", false, "1969-07-20T20:18:00Z", "1989-11-10T04:20:00Z"]
       data << "[#{row.map(&:inspect).join(', ')}]"
    end
    output + data.join(",\n  ") + "\n], validate: false)\n"
  end

  # Helper for insert_all output based on default factory values (issue #153)
  # Uses ISO 8601 format with timezone suffix (issue #111)
  def expected_insert_all_output(exclude_id_timestamps = true)
    output = "Sample.insert_all([\n  "
    data = []
    (1..3).each do |i|
      row = if exclude_id_timestamps
              # Expect integer: 42, ISO 8601 format with timezone
              { string: "string", text: "text", integer: 42, float: 3.14, decimal: "2.72", datetime: "1776-07-04T19:14:00Z", time: "2000-01-01T03:15:00Z", date: "1863-11-19", binary: "binary", boolean: false }
            else
              { id: i, string: "string", text: "text", integer: 42, float: 3.14, decimal: "2.72", datetime: "1776-07-04T19:14:00Z", time: "2000-01-01T03:15:00Z", date: "1863-11-19", binary: "binary", boolean: false, created_at: "1969-07-20T20:18:00Z", updated_at: "1989-11-10T04:20:00Z" }
            end
      data << "{#{row.map { |k, v| "#{k}: #{v.inspect}" }.join(', ')}}"
    end
    output + data.join(",\n  ") + "\n])\n"
  end


  describe '.dump' do

    context 'without file option' do
       before(:each) { FactoryBot.create_list(:sample, 3) } # Create 3 standard samples
      it 'should return the dump of the models passed in' do
        expect(SeedDump.dump(Sample)).to eq(expected_output) # Expects 3 standard samples
      end
    end

    context 'with file option' do
      let(:tempfile) { Tempfile.new(['seed_dump_test', '.rb']) }
      let(:filename) { tempfile.path }

      before(:each) { FactoryBot.create_list(:sample, 3) } # Create 3 standard samples

      after do
        tempfile.close
        tempfile.unlink
      end

      it 'should dump the models to the specified file' do
        SeedDump.dump(Sample, file: filename)
        expect(File.read(filename)).to eq(expected_output) # Expects 3 standard samples
      end

      context 'with append option' do
        it 'should append to the file rather than overwriting it' do
          # before(:each) creates 3 records
          SeedDump.dump(Sample, file: filename) # Dumps the 3 records
          # Second dump should dump the same 3 records again
          SeedDump.dump(Sample, file: filename, append: true)
          expect(File.read(filename)).to eq(expected_output + expected_output) # Expects 2 sets of 3 standard samples
        end
      end

      context 'with non-seekable files like /dev/stdout (issue #150)' do
        # Issue #150: Using w+ mode fails when writing to pipes because
        # pipes are not seekable. We should use w mode (write-only) instead.
        it 'should open files in write-only mode (w) not read+write mode (w+)' do
          # Verify File.open is called with 'w' mode, not 'w+'
          expect(File).to receive(:open).with(filename, 'w').and_call_original
          SeedDump.dump(Sample, file: filename)
        end

        it 'should open files in append mode (a) not read+append mode (a+)' do
          # Verify File.open is called with 'a' mode, not 'a+'
          expect(File).to receive(:open).with(filename, 'a').and_call_original
          SeedDump.dump(Sample, file: filename, append: true)
        end
      end
    end

    context 'ActiveRecord relation' do
      it 'should return nil if the count is 0' do
        expect(SeedDump.dump(EmptyModel)).to be_nil
      end

      context 'with an order parameter' do
        before(:each) do
          # Create samples with specific orderable values (0, 1, 2)
          3.times { |i| FactoryBot.create(:sample, integer: i) }
        end

        it 'should dump the models in the specified order' do
          # Define expected output based on descending integer order (2, 1, 0)
          # Uses ISO 8601 format with timezone suffix (issue #111)
          expected_desc_output = "Sample.create!([\n  "
          data = 2.downto(0).map do |i|
            "{string: \"string\", text: \"text\", integer: #{i}, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04T19:14:00Z\", time: \"2000-01-01T03:15:00Z\", date: \"1863-11-19\", binary: \"binary\", boolean: false}"
          end
          expected_desc_output += data.join(",\n  ") + "\n])\n"

          expect(SeedDump.dump(Sample.order('integer DESC'))).to eq(expected_desc_output)
        end
      end

      context 'without an order parameter' do
         before(:each) { FactoryBot.create_list(:sample, 3) } # Create 3 standard samples
        it 'should dump the models sorted by primary key ascending' do
          expect(SeedDump.dump(Sample)).to eq(expected_output) # Expects 3 standard samples
        end
      end

      context 'with a limit parameter' do
        it 'should dump the number of models specified by the limit when the limit is smaller than the batch size' do
          # Create one sample record (integer will be 42 from factory)
          FactoryBot.create(:sample)
          # Expected output for a single record, ISO 8601 format with timezone
          expected_limit_1 = "Sample.create!([\n  {string: \"string\", text: \"text\", integer: 42, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04T19:14:00Z\", time: \"2000-01-01T03:15:00Z\", date: \"1863-11-19\", binary: \"binary\", boolean: false}\n])\n"
          expect(SeedDump.dump(Sample.limit(1))).to eq(expected_limit_1)
        end

        it 'should dump the number of models specified by the limit when the limit is larger than the batch size but not a multiple of the batch size' do
          # Create 4 samples (integer will be 42 from factory)
          4.times { FactoryBot.create(:sample) }
          # Expecting first 3 records with batch_size: 2 -> 2 create! calls
          # First batch: 2 records, Second batch: 1 record
          sample_data = "{string: \"string\", text: \"text\", integer: 42, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04T19:14:00Z\", time: \"2000-01-01T03:15:00Z\", date: \"1863-11-19\", binary: \"binary\", boolean: false}"
          expected_limit_3 = "Sample.create!([\n  #{sample_data},\n  #{sample_data}\n])\n"
          expected_limit_3 += "Sample.create!([\n  #{sample_data}\n])\n"

          expect(SeedDump.dump(Sample.limit(3), batch_size: 2)).to eq(expected_limit_3)
        end
      end
    end

    context 'with a batch_size parameter' do
       before(:each) { FactoryBot.create_list(:sample, 3) } # Create 3 standard samples
      it 'should not raise an exception' do
        expect { SeedDump.dump(Sample, batch_size: 100) }.not_to raise_error
      end

      it 'should not cause records to not be dumped' do
        expect(SeedDump.dump(Sample, batch_size: 2)).to include('string: "string"')
        expect(SeedDump.dump(Sample, batch_size: 1)).to include('string: "string"')
      end

      it 'should output separate create! calls for each batch (issue #127)' do
        result = SeedDump.dump(Sample, batch_size: 2)
        # With 3 records and batch_size: 2, we should have 2 create! calls:
        # - First batch with 2 records
        # - Second batch with 1 record
        expect(result.scan(/Sample\.create!\(/).count).to eq(2)
      end

      it 'should output all records in a single call when batch_size is larger than record count' do
        result = SeedDump.dump(Sample, batch_size: 100)
        # With 3 records and batch_size: 100, we should have 1 create! call
        expect(result.scan(/Sample\.create!\(/).count).to eq(1)
      end

      it 'should output one create! call per record when batch_size is 1' do
        result = SeedDump.dump(Sample, batch_size: 1)
        # With 3 records and batch_size: 1, we should have 3 create! calls
        expect(result.scan(/Sample\.create!\(/).count).to eq(3)
      end
    end

    context 'Array' do
       before(:each) { FactoryBot.create_list(:sample, 3) } # Create 3 standard samples
      it 'should return the dump of the models passed in' do
        # With batch_size: 2 and 3 records, we get 2 create! calls
        result = SeedDump.dump(Sample.all.to_a, batch_size: 2)
        expect(result).to include('Sample.create!')
        expect(result.scan(/Sample\.create!\(/).count).to eq(2)
      end

      it 'should return nil if the array is empty' do
        expect(SeedDump.dump([])).to be_nil
      end
    end

    context 'with an exclude parameter' do
       before(:each) { FactoryBot.create_list(:sample, 3) } # Create 3 standard samples
      it 'should exclude the specified attributes from the dump' do
        # Uses ISO 8601 format with timezone suffix (issue #111)
        expected_excluded_output = "Sample.create!([\n  {text: \"text\", integer: 42, decimal: \"2.72\", time: \"2000-01-01T03:15:00Z\", date: \"1863-11-19\", binary: \"binary\", boolean: false},\n  {text: \"text\", integer: 42, decimal: \"2.72\", time: \"2000-01-01T03:15:00Z\", date: \"1863-11-19\", binary: \"binary\", boolean: false},\n  {text: \"text\", integer: 42, decimal: \"2.72\", time: \"2000-01-01T03:15:00Z\", date: \"1863-11-19\", binary: \"binary\", boolean: false}\n])\n"
        expect(SeedDump.dump(Sample, exclude: [:id, :created_at, :updated_at, :string, :float, :datetime])).to eq(expected_excluded_output)
      end
    end

    context 'Range' do
      let(:range_sample_mock) do
        mock_class = Class.new do
          def self.name; "RangeSample"; end
          def self.<(other); other == ActiveRecord::Base; end
          def attributes
            {
              "range_with_end_included" => (1..3),
              "range_with_end_excluded" => (1...3),
              "positive_infinite_range" => (1..Float::INFINITY),
              "negative_infinite_range" => (-Float::INFINITY..1),
              "infinite_range" => (-Float::INFINITY..Float::INFINITY)
            }
          end
          def attribute_names; attributes.keys; end
        end
        Object.const_set("RangeSample", mock_class) unless defined?(RangeSample)
        RangeSample.new
      end

      it 'should dump an object with ranges' do
        expected_range_output = "RangeSample.create!([\n  {range_with_end_included: \"[1,3]\", range_with_end_excluded: \"[1,3)\", positive_infinite_range: \"[1,]\", negative_infinite_range: \"[,1]\", infinite_range: \"[,]\"}\n])\n"
        expect(SeedDump.dump([range_sample_mock])).to eq(expected_range_output)
      end
    end

    context 'ActionText::Content (issue #154)' do
      # Mock ActionText::Content class to simulate ActionText behavior
      before(:all) do
        unless defined?(ActionText::Content)
          module ActionText
            class Content
              def initialize(html)
                @html = html
              end

              def to_s
                @html
              end

              def inspect
                "#<ActionText::Content \"#{@html[0..20]}...\">"
              end
            end
          end
        end
      end

      let(:action_text_sample_mock) do
        mock_class = Class.new do
          def self.name; "ActionTextSample"; end
          def self.<(other); other == ActiveRecord::Base; end
          def is_a?(klass)
            return true if klass == ActiveRecord::Base
            super
          end
          def class
            ActionTextSample
          end
          def attributes
            {
              "name" => "article",
              "body" => ActionText::Content.new("<div>Hello <strong>World</strong></div>")
            }
          end
          def attribute_names; attributes.keys; end
        end
        Object.const_set("ActionTextSample", mock_class) unless defined?(ActionTextSample)
        ActionTextSample.new
      end

      it 'should dump ActionText::Content as its HTML string representation' do
        result = SeedDump.dump([action_text_sample_mock], exclude: [])
        expect(result).to include('body: "<div>Hello <strong>World</strong></div>"')
        expect(result).not_to include('#<ActionText::Content')
      end
    end

    context 'table without primary key (issue #167)' do
      before(:each) do
        CampaignsManager.create!(campaign_id: 1, manager_id: 1)
        CampaignsManager.create!(campaign_id: 2, manager_id: 2)
      end

      it 'should dump records without raising an error' do
        expect { SeedDump.dump(CampaignsManager) }.not_to raise_error
      end

      it 'should return the dump of the models' do
        result = SeedDump.dump(CampaignsManager, exclude: [])
        expect(result).to include('CampaignsManager.create!')
        expect(result).to include('campaign_id: 1')
        expect(result).to include('campaign_id: 2')
      end
    end

    context 'model with default_scope using select (issue #165)' do
      before(:each) do
        ScopedSelectSample.unscoped.create!(name: 'test1', description: 'desc1')
        ScopedSelectSample.unscoped.create!(name: 'test2', description: 'desc2')
      end

      it 'should dump records without raising a COUNT error' do
        expect { SeedDump.dump(ScopedSelectSample) }.not_to raise_error
      end

      it 'should return the dump of the models' do
        result = SeedDump.dump(ScopedSelectSample)
        expect(result).to include('ScopedSelectSample.create!')
        expect(result).to include('name: "test1"')
        expect(result).to include('name: "test2"')
      end
    end

    context 'activerecord-import' do
       before(:each) { FactoryBot.create_list(:sample, 3) } # Create 3 standard samples
      it 'should dump in the activerecord-import format when import is true' do
        expect(SeedDump.dump(Sample, import: true, exclude: [])).to eq(expected_import_output(false))
      end

      it 'should omit excluded columns if they are specified' do
        expect(SeedDump.dump(Sample, import: true, exclude: [:id, :created_at, :updated_at])).to eq(expected_import_output(true))
      end

      context 'should add the params to the output if they are specified' do
        it 'should dump in the activerecord-import format when import is true' do
          expect(SeedDump.dump(Sample, import: { validate: false }, exclude: [])).to eq(expected_import_output_with_options)
        end
      end
    end

    context 'insert_all (issue #153)' do
      before(:each) { FactoryBot.create_list(:sample, 3) } # Create 3 standard samples

      it 'should dump in the insert_all format when insert_all option is true' do
        expect(SeedDump.dump(Sample, insert_all: true)).to eq(expected_insert_all_output(true))
      end

      it 'should include all columns when exclude is empty' do
        expect(SeedDump.dump(Sample, insert_all: true, exclude: [])).to eq(expected_insert_all_output(false))
      end

      it 'should use Hash syntax (not Array syntax like activerecord-import)' do
        result = SeedDump.dump(Sample, insert_all: true)
        # insert_all uses Hash format: {key: value, ...}
        expect(result).to include('string: "string"')
        expect(result).not_to include('[:string')  # Not array format
      end

      it 'should not include column names header like activerecord-import does' do
        result = SeedDump.dump(Sample, insert_all: true)
        # activerecord-import format includes: Model.import([:col1, :col2], [...])
        # insert_all format is just: Model.insert_all([{...}, {...}])
        expect(result).not_to match(/insert_all\(\[:\w+/)
      end
    end

    context 'HABTM join models (issue #130)' do
      # Rails creates private constants like `Model::HABTM_OtherModels` for
      # has_and_belongs_to_many associations. These cannot be referenced directly
      # in seeds.rb because they're private. We need to use const_get instead.
      #
      # Instead of: Dealer::HABTM_UStations.create!([...])
      # We output:  Dealer.const_get('HABTM_UStations').create!([...])

      let(:habtm_mock_class) do
        Class.new do
          def self.name; "Dealer::HABTM_UStations"; end
          def self.<(other); other == ActiveRecord::Base; end
          def self.to_s; name; end
        end
      end

      let(:habtm_mock) do
        klass = habtm_mock_class
        mock_instance = Object.new
        mock_instance.define_singleton_method(:class) { klass }
        mock_instance.define_singleton_method(:is_a?) do |other|
          other == ActiveRecord::Base || super(other)
        end
        mock_instance.define_singleton_method(:attributes) do
          { "dealer_id" => 1, "ustation_id" => 2 }
        end
        mock_instance.define_singleton_method(:attribute_names) do
          ["dealer_id", "ustation_id"]
        end
        mock_instance
      end

      it 'should output const_get format for HABTM models' do
        result = SeedDump.dump([habtm_mock], exclude: [])
        # Should use const_get to access the private constant
        expect(result).to include("Dealer.const_get('HABTM_UStations').create!")
        expect(result).not_to include("Dealer::HABTM_UStations.create!")
      end

      it 'should include the record data' do
        result = SeedDump.dump([habtm_mock], exclude: [])
        expect(result).to include("dealer_id: 1")
        expect(result).to include("ustation_id: 2")
      end

      it 'should produce output that can be evaluated without NameError' do
        # Create a class structure with private constant to test const_get works
        # Use a plain Ruby class (not ActiveRecord) to avoid polluting AR.descendants
        test_parent = Class.new
        Object.const_set('TestDealerParent', test_parent)

        habtm_class = Class.new
        TestDealerParent.const_set('HABTM_Stations', habtm_class)
        TestDealerParent.send(:private_constant, 'HABTM_Stations')

        begin
          # Verify that const_get can access the private constant
          resolved_class = TestDealerParent.const_get('HABTM_Stations')
          expect(resolved_class).to eq(habtm_class)

          # Verify that direct reference WOULD fail (proving we need const_get)
          # Error message varies by Ruby/Rails version:
          # - "private constant" in newer versions
          # - "uninitialized constant" in older versions (private constants appear uninitialized)
          expect { eval("TestDealerParent::HABTM_Stations") }.to raise_error(NameError)

          # Now test that our dump output format works with the mock
          result = SeedDump.dump([habtm_mock], exclude: [])
          expect(result).to include("Dealer.const_get('HABTM_UStations').create!")

          # Verify the generated model reference pattern is syntactically valid Ruby
          # that would resolve correctly (we can't actually eval it without Dealer existing)
          expect(result).to match(/\w+\.const_get\('\w+'\)\.create!/)
        ensure
          TestDealerParent.send(:remove_const, 'HABTM_Stations') if TestDealerParent.const_defined?('HABTM_Stations', false)
          Object.send(:remove_const, 'TestDealerParent') if defined?(TestDealerParent)
        end
      end

      context 'with nested namespace' do
        let(:nested_habtm_mock_class) do
          Class.new do
            def self.name; "Admin::Dealers::Dealer::HABTM_UStations"; end
            def self.<(other); other == ActiveRecord::Base; end
            def self.to_s; name; end
          end
        end

        let(:nested_habtm_mock) do
          klass = nested_habtm_mock_class
          mock_instance = Object.new
          mock_instance.define_singleton_method(:class) { klass }
          mock_instance.define_singleton_method(:is_a?) do |other|
            other == ActiveRecord::Base || super(other)
          end
          mock_instance.define_singleton_method(:attributes) do
            { "dealer_id" => 1, "ustation_id" => 2 }
          end
          mock_instance.define_singleton_method(:attribute_names) do
            ["dealer_id", "ustation_id"]
          end
          mock_instance
        end

        it 'should handle deeply nested namespaces' do
          result = SeedDump.dump([nested_habtm_mock], exclude: [])
          expect(result).to include("Admin::Dealers::Dealer.const_get('HABTM_UStations').create!")
        end
      end
    end

    context 'serialized Hash in text field (issue #105)' do
      it 'should dump serialized fields as valid Ruby that can be loaded' do
        SerializedSample.create!(
          name: 'test',
          metadata: { 'key' => 'value', 'number' => 42, 'nested' => { 'a' => 1 } }
        )
        result = SeedDump.dump(SerializedSample)
        expect(result).to include('SerializedSample.create!')
        expect(result).to include('name: "test"')

        # The metadata field should be dumped as a valid Ruby Hash literal
        # Not as the raw JSON string or malformed output
        # Ruby's Hash#inspect uses ' => ' with spaces
        expect(result).to include('metadata: {"key" => "value"')
        expect(result).to include('"number" => 42')
        expect(result).to include('"nested" => {"a" => 1}')
      end

      it 'should produce output that can be evaluated as valid Ruby' do
        SerializedSample.create!(
          name: 'test',
          metadata: { 'key' => 'value', 'number' => 42, 'nested' => { 'a' => 1 } }
        )
        result = SeedDump.dump(SerializedSample)
        # The dump should produce valid Ruby syntax
        expect { eval(result) rescue NameError }.not_to raise_error
      end

      it 'should handle DateTime objects in serialized Hashes as ISO 8601 strings' do
        # The original issue #105 was about DateTime objects inside serialized Hashes
        # being output as unquoted datetime objects like: 2016-05-25 17:00:00 UTC
        # which isn't valid Ruby syntax. With JSON serialization, Rails stores these
        # as ISO 8601 strings in the database, which should be dumped correctly.
        SerializedSample.create!(
          name: 'audit_log',
          metadata: {
            'event' => 'update',
            'changed_at' => Time.utc(2016, 5, 25, 17, 0, 0).iso8601,
            'changes' => { 'status' => ['pending', 'completed'] }
          }
        )
        result = SeedDump.dump(SerializedSample)

        # Should include the datetime as a quoted string
        expect(result).to include('"changed_at" => "2016-05-25T17:00:00Z"')
        # The output should be valid Ruby
        expect { eval(result) rescue NameError }.not_to raise_error
      end

      context 'with Time objects nested in Hashes' do
        # This tests the core issue #105: Time objects inside Hashes produce
        # invalid Ruby when .inspect is called on the Hash.
        # e.g. {"changed_at" => 2016-05-25 17:00:00 UTC} is not valid Ruby
        let(:hash_with_time_mock) do
          mock_class = Class.new do
            def self.name; "HashWithTimeSample"; end
            def self.<(other); other == ActiveRecord::Base; end
            def is_a?(klass)
              return true if klass == ActiveRecord::Base
              super
            end
            def class
              HashWithTimeSample
            end
            def attributes
              {
                "name" => "audit_log",
                # This Hash contains actual Time objects, which would be
                # the case with YAML-serialized fields in older Rails
                "metadata" => {
                  "event" => "update",
                  "changed_at" => Time.utc(2016, 5, 25, 17, 0, 0),
                  "changes" => { "status" => ["pending", "completed"] }
                }
              }
            end
            def attribute_names; attributes.keys; end
          end
          Object.const_set("HashWithTimeSample", mock_class) unless defined?(HashWithTimeSample)
          HashWithTimeSample.new
        end

        it 'should produce valid Ruby when Hash contains Time objects' do
          result = SeedDump.dump([hash_with_time_mock], exclude: [])

          # The output should be valid Ruby syntax - this is the core bug
          # Without the fix, this produces: metadata: {"changed_at" => 2016-05-25 17:00:00 UTC}
          # which is a SyntaxError
          expect { eval(result) rescue NameError }.not_to raise_error
        end

        it 'should convert Time objects inside Hashes to ISO 8601 format' do
          result = SeedDump.dump([hash_with_time_mock], exclude: [])

          # Time objects should be converted to ISO 8601 strings
          expect(result).to match(/"changed_at" => "2016-05-25T17:00:00(\+00:00|Z)"/)
        end
      end

      context 'with BigDecimal objects nested in Hashes' do
        let(:hash_with_bigdecimal_mock) do
          mock_class = Class.new do
            def self.name; "HashWithBigDecimalSample"; end
            def self.<(other); other == ActiveRecord::Base; end
            def is_a?(klass)
              return true if klass == ActiveRecord::Base
              super
            end
            def class
              HashWithBigDecimalSample
            end
            def attributes
              {
                "name" => "pricing",
                "data" => {
                  "price" => BigDecimal("19.99"),
                  "tax_rate" => BigDecimal("0.08"),
                  "nested" => { "discount" => BigDecimal("5.00") }
                }
              }
            end
            def attribute_names; attributes.keys; end
          end
          Object.const_set("HashWithBigDecimalSample", mock_class) unless defined?(HashWithBigDecimalSample)
          HashWithBigDecimalSample.new
        end

        it 'should produce valid Ruby when Hash contains BigDecimal objects' do
          result = SeedDump.dump([hash_with_bigdecimal_mock], exclude: [])

          # The output should be valid Ruby syntax
          expect { eval(result) rescue NameError }.not_to raise_error
        end

        it 'should convert BigDecimal objects inside Hashes to string format' do
          result = SeedDump.dump([hash_with_bigdecimal_mock], exclude: [])

          # BigDecimal objects should be converted to strings
          expect(result).to include('"price" => "19.99"')
          expect(result).to include('"tax_rate" => "0.08"')
          expect(result).to include('"discount" => "5.0"')
        end
      end

      context 'with mixed types nested in Arrays' do
        let(:array_with_mixed_types_mock) do
          mock_class = Class.new do
            def self.name; "ArrayWithMixedTypesSample"; end
            def self.<(other); other == ActiveRecord::Base; end
            def is_a?(klass)
              return true if klass == ActiveRecord::Base
              super
            end
            def class
              ArrayWithMixedTypesSample
            end
            def attributes
              {
                "name" => "events",
                "timestamps" => [
                  Time.utc(2016, 1, 1, 0, 0, 0),
                  Time.utc(2016, 6, 15, 12, 30, 0),
                  Time.utc(2016, 12, 31, 23, 59, 59)
                ],
                "prices" => [
                  BigDecimal("10.00"),
                  BigDecimal("20.50"),
                  BigDecimal("30.99")
                ]
              }
            end
            def attribute_names; attributes.keys; end
          end
          Object.const_set("ArrayWithMixedTypesSample", mock_class) unless defined?(ArrayWithMixedTypesSample)
          ArrayWithMixedTypesSample.new
        end

        it 'should produce valid Ruby when Array contains Time/BigDecimal objects' do
          result = SeedDump.dump([array_with_mixed_types_mock], exclude: [])

          # The output should be valid Ruby syntax
          expect { eval(result) rescue NameError }.not_to raise_error
        end

        it 'should convert Time objects inside Arrays to ISO 8601 format' do
          result = SeedDump.dump([array_with_mixed_types_mock], exclude: [])

          expect(result).to include('"2016-01-01T00:00:00Z"')
          expect(result).to include('"2016-06-15T12:30:00Z"')
          expect(result).to include('"2016-12-31T23:59:59Z"')
        end

        it 'should convert BigDecimal objects inside Arrays to string format' do
          result = SeedDump.dump([array_with_mixed_types_mock], exclude: [])

          expect(result).to include('"10.0"')
          expect(result).to include('"20.5"')
          expect(result).to include('"30.99"')
        end
      end
    end

    context 'DateTime timezone preservation (issue #111)' do
      let(:datetime_sample_mock) do
        mock_class = Class.new do
          def self.name; "DateTimeSample"; end
          def self.<(other); other == ActiveRecord::Base; end
          def is_a?(klass)
            return true if klass == ActiveRecord::Base
            super
          end
          def class
            DateTimeSample
          end
          def attributes
            {
              "name" => "test",
              # UTC datetime - should preserve timezone info in dump
              "scheduled_at" => Time.utc(2016, 8, 12, 2, 20, 20)
            }
          end
          def attribute_names; attributes.keys; end
        end
        Object.const_set("DateTimeSample", mock_class) unless defined?(DateTimeSample)
        DateTimeSample.new
      end

      it 'should include timezone information in datetime dumps' do
        result = SeedDump.dump([datetime_sample_mock], exclude: [])
        # The datetime should include timezone info (UTC) so it can be reimported correctly
        # Format should be ISO 8601: "2016-08-12T02:20:20Z" or similar with timezone
        expect(result).to match(/scheduled_at: "2016-08-12T02:20:20(\+00:00|Z)"/)
      end

      it 'should preserve non-UTC timezone information' do
        # Create a mock with a non-UTC timezone
        non_utc_mock_class = Class.new do
          def self.name; "NonUtcSample"; end
          def self.<(other); other == ActiveRecord::Base; end
          def is_a?(klass)
            return true if klass == ActiveRecord::Base
            super
          end
          def class
            NonUtcSample
          end
          def attributes
            {
              "name" => "test",
              # Pacific time (-08:00)
              "scheduled_at" => Time.new(2016, 8, 12, 2, 20, 20, "-08:00")
            }
          end
          def attribute_names; attributes.keys; end
        end
        Object.const_set("NonUtcSample", non_utc_mock_class) unless defined?(NonUtcSample)
        non_utc_sample = NonUtcSample.new

        result = SeedDump.dump([non_utc_sample], exclude: [])
        # Should include the timezone offset
        expect(result).to match(/scheduled_at: "2016-08-12T02:20:20-08:00"/)
      end
    end

    context 'CarrierWave uploader columns (issue #117)' do
      # CarrierWave mounts uploaders on models which override the attribute getter.
      # When record.attributes is called, it may return nil or an uploader object
      # instead of the raw filename string. We need to detect this and extract the identifier.
      #
      # The issue reports that CarrierWave columns "always dump to 'nil'" - this happens
      # because record.attributes bypasses the CarrierWave getter and returns the raw
      # @attributes value, which may be nil even when the uploader has a file.

      before(:all) do
        # Mock CarrierWave::Uploader::Base if not already defined
        unless defined?(CarrierWave::Uploader::Base)
          module CarrierWave
            module Uploader
              class Base
                attr_reader :identifier

                def initialize(identifier)
                  @identifier = identifier
                end

                def inspect
                  "#<CarrierWave::Uploader::Base identifier=#{@identifier.inspect}>"
                end

                def to_s
                  # CarrierWave's to_s returns the URL, not the identifier
                  "/uploads/#{@identifier}"
                end
              end
            end
          end
        end
      end

      context 'when record.attributes returns nil but getter returns uploader (the reported bug)' do
        # This is the actual bug reported in issue #117:
        # record.attributes['avatar'] returns nil, but record.avatar returns an uploader
        # with an identifier. We need to call the getter to get the real value.
        let(:nil_attributes_mock) do
          uploader = CarrierWave::Uploader::Base.new("avatar123.jpg")
          mock_class = Class.new do
            def self.name; "NilAttributesSample"; end
            def self.<(other); other == ActiveRecord::Base; end
            def is_a?(klass)
              return true if klass == ActiveRecord::Base
              super
            end
            def class
              NilAttributesSample
            end
          end

          Object.const_set("NilAttributesSample", mock_class) unless defined?(NilAttributesSample)
          instance = NilAttributesSample.new

          # record.attributes returns nil for the avatar column
          instance.define_singleton_method(:attributes) do
            { "name" => "user1", "avatar" => nil }
          end
          instance.define_singleton_method(:attribute_names) { ["name", "avatar"] }

          # But record.avatar returns the uploader with the actual filename
          instance.define_singleton_method(:avatar) { uploader }

          instance
        end

        it 'should dump the uploader identifier even when attributes returns nil' do
          result = SeedDump.dump([nil_attributes_mock], exclude: [])
          # Should include the filename from the uploader, not nil
          expect(result).to include('avatar: "avatar123.jpg"')
          expect(result).not_to include('avatar: nil')
        end

        it 'should produce valid Ruby' do
          result = SeedDump.dump([nil_attributes_mock], exclude: [])
          expect { eval(result) rescue NameError }.not_to raise_error
        end
      end

      context 'when record.attributes returns an uploader object directly' do
        let(:uploader_in_attributes_mock) do
          mock_class = Class.new do
            def self.name; "UploaderInAttributesSample"; end
            def self.<(other); other == ActiveRecord::Base; end
            def is_a?(klass)
              return true if klass == ActiveRecord::Base
              super
            end
            def class
              UploaderInAttributesSample
            end
            def attributes
              {
                "name" => "user1",
                # CarrierWave uploader object in the attributes hash
                "avatar" => CarrierWave::Uploader::Base.new("avatar456.jpg")
              }
            end
            def attribute_names; attributes.keys; end
          end
          Object.const_set("UploaderInAttributesSample", mock_class) unless defined?(UploaderInAttributesSample)
          UploaderInAttributesSample.new
        end

        it 'should dump CarrierWave uploader columns as the identifier string' do
          result = SeedDump.dump([uploader_in_attributes_mock], exclude: [])
          # Should include the filename, not the uploader object's inspect output
          expect(result).to include('avatar: "avatar456.jpg"')
          expect(result).not_to include('#<CarrierWave')
          expect(result).not_to include('/uploads/')
        end
      end

      context 'with no file uploaded (nil identifier)' do
        let(:no_file_mock) do
          uploader = CarrierWave::Uploader::Base.new(nil)
          mock_class = Class.new do
            def self.name; "NoFileSample"; end
            def self.<(other); other == ActiveRecord::Base; end
            def is_a?(klass)
              return true if klass == ActiveRecord::Base
              super
            end
            def class
              NoFileSample
            end
          end
          Object.const_set("NoFileSample", mock_class) unless defined?(NoFileSample)
          instance = NoFileSample.new
          instance.define_singleton_method(:attributes) do
            { "name" => "user2", "avatar" => nil }
          end
          instance.define_singleton_method(:attribute_names) { ["name", "avatar"] }
          instance.define_singleton_method(:avatar) { uploader }
          instance
        end

        it 'should handle CarrierWave uploaders with nil identifier' do
          result = SeedDump.dump([no_file_mock], exclude: [])
          expect(result).to include('avatar: nil')
          expect(result).not_to include('#<CarrierWave')
        end
      end
    end

    context 'created_on/updated_on columns (issue #128)' do
      # Rails supports both created_at/updated_at AND created_on/updated_on as
      # timestamp columns. Both should be excluded by default since they're
      # auto-generated by Rails and should not be manually seeded.

      before(:each) do
        TimestampOnSample.create!(name: 'test1')
        TimestampOnSample.create!(name: 'test2')
      end

      it 'should exclude created_on and updated_on columns by default' do
        result = SeedDump.dump(TimestampOnSample)
        expect(result).to include('TimestampOnSample.create!')
        expect(result).to include('name: "test1"')
        expect(result).to include('name: "test2"')
        # These columns should be excluded by default (like created_at/updated_at)
        expect(result).not_to include('created_on')
        expect(result).not_to include('updated_on')
      end

      it 'should include created_on/updated_on when explicitly excluded from exclude list' do
        result = SeedDump.dump(TimestampOnSample, exclude: [:id])
        expect(result).to include('created_on')
        expect(result).to include('updated_on')
      end
    end
  end
end
