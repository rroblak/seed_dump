require 'spec_helper'

describe SeedDump do

  # Helper for expected output based on default factory values (integer: 42)
  # Expect format WITHOUT UTC suffix, matching strftime and Rails 7+ to_fs(:db)
  def expected_output(include_id = false, id_offset = 0, count = 3)
      output = "Sample.create!([\n  "
      data = []
      start_id = 1 + id_offset
      end_id = count + id_offset # Adjust end based on count
      (start_id..end_id).each do |i|
        # Expect integer: 42, no UTC suffix
        data << "{#{include_id ? "id: #{i}, " : ''}string: \"string\", text: \"text\", integer: 42, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false}"
      end
      output + data.join(",\n  ") + "\n])\n"
  end

  # Helper for activerecord-import output based on default factory values
  # Expect format WITHOUT UTC suffix
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
               # Expect integer: 42, no UTC suffix
               ["string", "text", 42, 3.14, "2.72", "1776-07-04 19:14:00", "2000-01-01 03:15:00", "1863-11-19", "binary", false]
             else
               # Expect integer: 42, no UTC suffix
               [i, "string", "text", 42, 3.14, "2.72", "1776-07-04 19:14:00", "2000-01-01 03:15:00", "1863-11-19", "binary", false, "1969-07-20 20:18:00", "1989-11-10 04:20:00"]
             end
       data << "[#{row.map(&:inspect).join(', ')}]"
    end
    output + data.join(",\n  ") + "\n])\n"
  end

  # Helper for activerecord-import output with options
  # Expect format WITHOUT UTC suffix
  def expected_import_output_with_options
    columns = [:id, :string, :text, :integer, :float, :decimal, :datetime, :time, :date, :binary, :boolean, :created_at, :updated_at]
    output = "Sample.import([#{columns.map(&:inspect).join(', ')}], [\n  "
    data = []
    (1..3).each do |i|
       # Expect integer: 42, no UTC suffix
       row = [i, "string", "text", 42, 3.14, "2.72", "1776-07-04 19:14:00", "2000-01-01 03:15:00", "1863-11-19", "binary", false, "1969-07-20 20:18:00", "1989-11-10 04:20:00"]
       data << "[#{row.map(&:inspect).join(', ')}]"
    end
    output + data.join(",\n  ") + "\n], validate: false)\n"
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
          # Expect format WITHOUT UTC suffix
          expected_desc_output = "Sample.create!([\n  "
          data = 2.downto(0).map do |i|
            "{string: \"string\", text: \"text\", integer: #{i}, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false}"
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
          # Expected output for a single record, no UTC suffix
          expected_limit_1 = "Sample.create!([\n  {string: \"string\", text: \"text\", integer: 42, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false}\n])\n"
          expect(SeedDump.dump(Sample.limit(1))).to eq(expected_limit_1)
        end

        it 'should dump the number of models specified by the limit when the limit is larger than the batch size but not a multiple of the batch size' do
          # Create 4 samples (integer will be 42 from factory)
          4.times { FactoryBot.create(:sample) }
          # Expecting first 3 records created (IDs 1, 2, 3)
          expected_limit_3 = "Sample.create!([\n  "
          data = (1..3).map do |i|
             # Use integer: 42 as defined in the factory, no UTC suffix
             "{string: \"string\", text: \"text\", integer: 42, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false}"
          end
          expected_limit_3 += data.join(",\n  ") + "\n])\n"

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
        expect(SeedDump.dump(Sample, batch_size: 2)).to eq(expected_output) # Expects 3 standard samples
        expect(SeedDump.dump(Sample, batch_size: 1)).to eq(expected_output) # Expects 3 standard samples
      end
    end

    context 'Array' do
       before(:each) { FactoryBot.create_list(:sample, 3) } # Create 3 standard samples
      it 'should return the dump of the models passed in' do
        expect(SeedDump.dump(Sample.all.to_a, batch_size: 2)).to eq(expected_output) # Expects 3 standard samples
      end

      it 'should return nil if the array is empty' do
        expect(SeedDump.dump([])).to be_nil
      end
    end

    context 'with an exclude parameter' do
       before(:each) { FactoryBot.create_list(:sample, 3) } # Create 3 standard samples
      it 'should exclude the specified attributes from the dump' do
        # Expect format WITHOUT UTC suffix
        expected_excluded_output = "Sample.create!([\n  {text: \"text\", integer: 42, decimal: \"2.72\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false},\n  {text: \"text\", integer: 42, decimal: \"2.72\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false},\n  {text: \"text\", integer: 42, decimal: \"2.72\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false}\n])\n"
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
  end
end
