require 'spec_helper'

describe SeedDump do

  describe '.dump' do
    before do
      Rails.application.eager_load!

      create_db

      3.times { FactoryGirl.create(:sample) }

      @expected_output = "Sample.create!([\n  {string: \"string\", text: \"text\", integer: 42, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false},\n  {string: \"string\", text: \"text\", integer: 42, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false},\n  {string: \"string\", text: \"text\", integer: 42, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false}\n])\n"
    end

    context 'without file option' do
      it 'should return the dump of the models passed in' do
        SeedDump.dump(Sample).should eq(@expected_output)
      end
    end

    context 'with file option' do
      before do
        @filename = Dir::Tmpname.make_tmpname(File.join(Dir.tmpdir, 'foo'), nil)
      end

      after do
        File.unlink(@filename)
      end

      it 'should dump the models to the specified file' do
        SeedDump.dump(Sample, file: @filename)

        File.open(@filename) { |file| file.read.should eq(@expected_output) }
      end

      context 'with append option' do
        it 'should append to the file rather than overwriting it' do
          SeedDump.dump(Sample, file: @filename)
          SeedDump.dump(Sample, file: @filename, append: true)

          File.open(@filename) { |file| file.read.should eq(@expected_output + @expected_output) }
        end
      end
    end

    context 'ActiveRecord relation' do
      it 'should return nil if the count is 0' do
        SeedDump.dump(EmptyModel).should be(nil)
      end

      context 'with an order parameter' do
        it 'should dump the models in the specified order' do
          Sample.delete_all
          samples = 3.times {|i| FactoryGirl.create(:sample, integer: i) }

          SeedDump.dump(Sample.order('integer DESC')).should eq("Sample.create!([\n  {string: \"string\", text: \"text\", integer: 2, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false},\n  {string: \"string\", text: \"text\", integer: 1, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false},\n  {string: \"string\", text: \"text\", integer: 0, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false}\n])\n")
        end
      end

      context 'without an order parameter' do
        it 'should dump the models sorted by primary key ascending' do
          Sample.delete_all
          samples = 3.times {|i| FactoryGirl.create(:sample, integer: i) }

          SeedDump.dump(Sample).should eq("Sample.create!([\n  {string: \"string\", text: \"text\", integer: 0, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false},\n  {string: \"string\", text: \"text\", integer: 1, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false},\n  {string: \"string\", text: \"text\", integer: 2, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false}\n])\n")
        end
      end

      context 'with a limit parameter' do
        it 'should dump the number of models specified by the limit when the limit is smaller than the batch size' do
          expected_output = "Sample.create!([\n  {string: \"string\", text: \"text\", integer: 42, float: 3.14, decimal: \"2.72\", datetime: \"1776-07-04 19:14:00\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false}\n])\n"

          SeedDump.dump(Sample.limit(1)).should eq(expected_output)
        end

        it 'should dump the number of models specified by the limit when the limit is larger than the batch size but not a multiple of the batch size' do
          Sample.delete_all
          4.times { FactoryGirl.create(:sample) }

          SeedDump.dump(Sample.limit(3), batch_size: 2).should eq(@expected_output)
        end
      end
    end

    context 'with a batch_size parameter' do
      it 'should not raise an exception' do
        SeedDump.dump(Sample, batch_size: 100)
      end

      it 'should not cause records to not be dumped' do
        SeedDump.dump(Sample, batch_size: 2).should eq(@expected_output)

        SeedDump.dump(Sample, batch_size: 1).should eq(@expected_output)
      end
    end

    context 'Array' do
      it 'should return the dump of the models passed in' do
        SeedDump.dump(Sample.all.to_a, batch_size: 2).should eq(@expected_output)
      end

      it 'should return nil if the array is empty' do
        SeedDump.dump([]).should be(nil)
      end
    end

    context 'with an exclude parameter' do
      it 'should exclude the specified attributes from the dump' do
        expected_output = "Sample.create!([\n  {text: \"text\", integer: 42, decimal: \"2.72\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false},\n  {text: \"text\", integer: 42, decimal: \"2.72\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false},\n  {text: \"text\", integer: 42, decimal: \"2.72\", time: \"2000-01-01 03:15:00\", date: \"1863-11-19\", binary: \"binary\", boolean: false}\n])\n"

        SeedDump.dump(Sample, exclude: [:id, :created_at, :updated_at, :string, :float, :datetime]).should eq(expected_output)
      end
    end

    context 'Range' do
      it 'should dump a class with ranges' do
        expected_output = "RangeSample.create!([\n  {range_with_end_included: \"[1,3]\", range_with_end_excluded: \"[1,3)\", positive_infinite_range: \"[1,]\", negative_infinite_range: \"[,1]\", infinite_range: \"[,]\"}\n])\n"

        SeedDump.dump([RangeSample.new]).should eq(expected_output)
      end
    end
  end
end

class RangeSample
  def attributes
    {
      "range_with_end_included" => (1..3),
      "range_with_end_excluded" => (1...3),
      "positive_infinite_range" => (1..Float::INFINITY),
      "negative_infinite_range" => (-Float::INFINITY..1),
      "infinite_range" => (-Float::INFINITY..Float::INFINITY)
    }
  end
end
