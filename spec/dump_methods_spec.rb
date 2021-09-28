require 'spec_helper'

describe SeedDump do
  def expected_output(operation: 'create!', include_id: false, id_offset: 0)
    output = "Sample.#{operation}([\n  "

    data = []
    ((1 + id_offset)..(3 + id_offset)).each do |i|
      data << "{#{include_id ? "id: #{i}, " : ''}string: \"string\", text: \"text\", integer: 42, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false}"
    end

    "#{output}#{data.join(",\n  ")}\n])\n"
  end

  describe '.dump' do
    before do
      Rails.application.eager_load!

      create_db

      FactoryBot.create_list(:sample, 3)
    end

    context 'without file option' do
      it 'returns the dump of the models passed in' do
        described_class.dump(Sample).should eq(expected_output)
      end
    end

    context 'with file option' do
      before do
        @filename = Tempfile.new(File.join(Dir.tmpdir, 'foo'), nil)
      end

      after do
        File.unlink(@filename)
      end

      it 'dumps the models to the specified file' do
        described_class.dump(Sample, file: @filename)

        File.open(@filename) { |file| file.read.should eq(expected_output) }
      end

      context 'with append option' do
        it 'appends to the file rather than overwriting it' do
          described_class.dump(Sample, file: @filename)
          described_class.dump(Sample, file: @filename, append: true)

          File.open(@filename) { |file| file.read.should eq(expected_output + expected_output) }
        end
      end
    end

    context 'with file option and file split option' do
      let(:file_path) { Tempfile.new('./foo').path }
      let(:result_file_path) { [file_path, '1'].join('_') }

      after do
        File.unlink(result_file_path)
      end

      it 'stores the information in file_path with file index' do
        described_class.dump(Sample, file: file_path, file_split_limit: 5)

        File.open(result_file_path) { |file| expect(file.read).to eq(expected_output) }
      end
    end

    context 'ActiveRecord relation' do
      it 'returns nil if the count is 0' do
        described_class.dump(EmptyModel).should be(nil)
      end

      context 'with an order parameter' do
        it 'dumps the models in the specified order' do
          Sample.delete_all
          samples = 3.times { |i| FactoryBot.create(:sample, integer: i) }

          described_class.dump(Sample.order('integer DESC')).should eq("Sample.create!([\n  {string: \"string\", text: \"text\", integer: 2, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false},\n  {string: \"string\", text: \"text\", integer: 1, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false},\n  {string: \"string\", text: \"text\", integer: 0, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false}\n])\n")
        end
      end

      context 'without an order parameter' do
        it 'dumps the models sorted by primary key ascending' do
          described_class.dump(Sample).should eq(expected_output)
        end
      end

      context 'with a limit parameter' do
        it 'dumps the number of models specified by the limit when the limit is smaller than the batch size' do
          expected_output = "Sample.create!([\n  {string: \"string\", text: \"text\", integer: 42, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false}\n])\n"

          described_class.dump(Sample.limit(1)).should eq(expected_output)
        end

        it 'dumps the number of models specified by the limit when the limit is larger than the batch size but not a multiple of the batch size' do
          Sample.delete_all
          FactoryBot.create_list(:sample, 4)

          described_class.dump(Sample.limit(3), batch_size: 2).should eq(
            expected_output(include_id: false,
                            id_offset: 3)
          )
        end
      end
    end

    context 'with a batch_size parameter' do
      it 'does not raise an exception' do
        described_class.dump(Sample, batch_size: 100)
      end

      it 'does not cause records to not be dumped' do
        described_class.dump(Sample, batch_size: 2).should eq(expected_output)

        described_class.dump(Sample, batch_size: 1).should eq(expected_output)
      end
    end

    context 'Array' do
      it 'returns the dump of the models passed in' do
        described_class.dump(Sample.all.to_a, batch_size: 2).should eq(expected_output)
      end

      it 'returns nil if the array is empty' do
        described_class.dump([]).should be(nil)
      end
    end

    context 'with an exclude parameter' do
      it 'excludes the specified attributes from the dump' do
        expected_output = "Sample.create!([\n  {text: \"text\", integer: 42, decimal: \"2.72\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false},\n  {text: \"text\", integer: 42, decimal: \"2.72\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false},\n  {text: \"text\", integer: 42, decimal: \"2.72\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false}\n])\n"

        described_class.dump(Sample,
                             exclude: %i[id created_at updated_at string float datetime]).should eq(expected_output)
      end
    end

    context 'Range' do
      it 'dumps a class with ranges' do
        expected_output = "RangeSample.create!([\n  {range_with_end_included: \"[1,3]\", range_with_end_excluded: \"[1,3)\", positive_infinite_range: \"[1,]\", negative_infinite_range: \"[,1]\", infinite_range: \"[,]\"}\n])\n"

        described_class.dump([RangeSample.new]).should eq(expected_output)
      end
    end

    context 'activerecord-insert-all' do
      it 'dumps in the activerecord-insert-all format when insert-all is true' do
        described_class.dump(Sample, insert_all: true).should eq(expected_output(operation: 'insert_all'))
      end
    end

    context 'activerecord-import' do
      it 'dumps in the activerecord-import format when import is true' do
        described_class.dump(Sample, import: true, exclude: []).should eq <<~RUBY
          Sample.import([:id, :string, :text, :integer, :float, :decimal, :datetime, :time, :date, :binary, :boolean, :created_at, :updated_at], [
            [1, "string", "text", 42, 3.14, "2.72", "1776-07-04 19:14:00", "2000-01-01 03:15:00", "1863-11-19", "binary", false, "1969-07-20 20:18:00", "1989-11-10 04:20:00"],
            [2, "string", "text", 42, 3.14, "2.72", "1776-07-04 19:14:00", "2000-01-01 03:15:00", "1863-11-19", "binary", false, "1969-07-20 20:18:00", "1989-11-10 04:20:00"],
            [3, "string", "text", 42, 3.14, "2.72", "1776-07-04 19:14:00", "2000-01-01 03:15:00", "1863-11-19", "binary", false, "1969-07-20 20:18:00", "1989-11-10 04:20:00"]
          ])
        RUBY
      end

      it 'omits excluded columns if they are specified' do
        described_class.dump(Sample, import: true, exclude: %i[id created_at updated_at]).should eq <<~RUBY
          Sample.import([:string, :text, :integer, :float, :decimal, :datetime, :time, :date, :binary, :boolean], [
            ["string", "text", 42, 3.14, "2.72", "1776-07-04 19:14:00", "2000-01-01 03:15:00", "1863-11-19", "binary", false],
            ["string", "text", 42, 3.14, "2.72", "1776-07-04 19:14:00", "2000-01-01 03:15:00", "1863-11-19", "binary", false],
            ["string", "text", 42, 3.14, "2.72", "1776-07-04 19:14:00", "2000-01-01 03:15:00", "1863-11-19", "binary", false]
          ])
        RUBY
      end

      context 'should add the params to the output if they are specified' do
        it 'dumps in the activerecord-import format when import is true' do
          described_class.dump(Sample, import: { validate: false }, exclude: []).should eq <<~RUBY
            Sample.import([:id, :string, :text, :integer, :float, :decimal, :datetime, :time, :date, :binary, :boolean, :created_at, :updated_at], [
              [1, "string", "text", 42, 3.14, "2.72", "1776-07-04 19:14:00", "2000-01-01 03:15:00", "1863-11-19", "binary", false, "1969-07-20 20:18:00", "1989-11-10 04:20:00"],
              [2, "string", "text", 42, 3.14, "2.72", "1776-07-04 19:14:00", "2000-01-01 03:15:00", "1863-11-19", "binary", false, "1969-07-20 20:18:00", "1989-11-10 04:20:00"],
              [3, "string", "text", 42, 3.14, "2.72", "1776-07-04 19:14:00", "2000-01-01 03:15:00", "1863-11-19", "binary", false, "1969-07-20 20:18:00", "1989-11-10 04:20:00"]
            ], validate: false)
          RUBY
        end
      end
    end
  end
end

class RangeSample
  def attributes
    {
      'range_with_end_included' => (1..3),
      'range_with_end_excluded' => (1...3),
      'positive_infinite_range' => (1..Float::INFINITY),
      'negative_infinite_range' => (-Float::INFINITY..1),
      'infinite_range' => (-Float::INFINITY..Float::INFINITY)
    }
  end
end
