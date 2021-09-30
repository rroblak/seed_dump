class SeedDump
  module DumpMethods
    APPEND_FILE_MODE = 'a+'.freeze
    OVERWRITE_FILE_MODE = 'w+'.freeze
    include Enumeration

    def dump(records, options = {})
      return nil if records.count.zero?

      io = open_io(options)

      write_records_to_io(records, io, options)
    ensure
      io.close if io.present?
    end

    private

    def dump_record(record, options)
      attribute_strings = []

      # We select only string attribute names to avoid conflict
      # with the composite_primary_keys gem (it returns composite
      # primary key attribute names as hashes).
      record.attributes.select { |key| key.is_a?(String) || key.is_a?(Symbol) }.each do |attribute, value|
        unless options[:exclude].include?(attribute.to_sym)
          attribute_strings << dump_attribute_new(attribute, value,
                                                  options)
        end
      end

      open_character, close_character = options[:import] ? ['[', ']'] : ['{', '}']

      "#{open_character}#{attribute_strings.join(', ')}#{close_character}"
    end

    def dump_attribute_new(attribute, value, options)
      options[:import] ? value_to_s(value) : "#{attribute}: #{value_to_s(value)}"
    end

    def value_to_s(value)
      value = case value
              when BigDecimal, IPAddr
                value.to_s
              when Date, Time, DateTime
                value.to_s(:db)
              when Range
                range_to_string(value)
              when ->(v) { v.class.ancestors.map(&:to_s).include?('RGeo::Feature::Instance') }
                value.to_s
              else
                value
              end

      value.inspect
    end

    def range_to_string(object)
      from = object.begin.respond_to?(:infinite?) && object.begin.infinite? ? '' : object.begin
      to   = object.end.respond_to?(:infinite?) && object.end.infinite? ? '' : object.end
      "[#{from},#{to}#{object.exclude_end? ? ')' : ']'}"
    end

    def open_io(options)
      if options[:file].present?
        mode = options[:append] ? APPEND_FILE_MODE : OVERWRITE_FILE_MODE
        file_path = if options[:file_split_limit]
                      file_path_with_file_index(options)
                    else
                      options[:file]
                    end

        File.open(file_path, mode)
      else
        StringIO.new('', OVERWRITE_FILE_MODE)
      end
    end

    def file_path_with_file_index(options)
      base_name = File.basename(options[:file], '.*')
      options[:file].reverse.sub(
        base_name.reverse,
        [
          base_name,
          (options[:current_file_index]&.to_i || 1)
        ].join('_').reverse
      ).reverse
    end

    def write_records_to_io(records, io, options)
      options[:exclude] ||= %i[id created_at updated_at]

      setup_io(io, options, records)

      enumeration_method = if records.is_a?(ActiveRecord::Relation) || records.is_a?(Class)
                             :active_record_enumeration
                           else
                             :enumerable_enumeration
                           end

      send(enumeration_method, records, io, options) do |record_strings, last_batch, file_split_required|
        io.write(record_strings.join(",\n  "))

        io.write(",\n  ") unless last_batch

        if options[:file].present? && file_split_required
          options[:current_file_index] = ((options[:current_file_index]&.to_i || 1) + 1)
          io.write("\n]#{active_record_import_options(options)})\n")
          io = open_io(options)
          setup_io(io, options, records)
        end
      end

      io.write("\n]#{active_record_import_options(options)})\n")

      if options[:file].present?
        nil
      else
        io.rewind
        io.read
      end
    end

    def setup_io(io, options, records)
      method = chosen_creation_method(options)
      io.write("#{model_for(records)}.#{method}(")
      if options[:import]
        io.write("[#{attribute_names(records, options).map { |name| name.to_sym.inspect }.join(', ')}], ")
      end
      io.write("[\n  ")
    end

    def chosen_creation_method(options)
      if options[:import]
        'import'
      elsif options[:insert_all]
        'insert_all'
      else
        'create!'
      end
    end

    def active_record_import_options(options)
      return unless options[:import].is_a?(Hash) || options[:import_options].present?

      if options[:import].is_a?(Hash)
        ', ' + options[:import].map { |key, value| "#{key}: #{value}" }.join(', ')
      else
        ', ' + options[:import_options]
      end
    end

    def attribute_names(records, options)
      attribute_names = if records.is_a?(ActiveRecord::Relation) || records.is_a?(Class)
                          records.attribute_names
                        else
                          records[0].attribute_names
                        end

      attribute_names.reject { |name| options[:exclude].include?(name.to_sym) }
    end

    def model_for(records)
      if records.is_a?(Class)
        records
      elsif records.respond_to?(:model)
        records.model
      else
        records[0].class
      end
    end
  end
end
