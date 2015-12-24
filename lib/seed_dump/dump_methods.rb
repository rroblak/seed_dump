class SeedDump
  module DumpMethods
    include Enumeration

    def dump(records, options = {})
      return nil if records.count == 0

      io = open_io(options)

      write_records_to_io(records, io, options, true)

      ensure
        io.close if io.present?
    end

    private

    def dump_record(record, io, options)
      attribute_strings = []


      if record.respond_to? 'attributes'
      # We select only string attribute names to avoid conflict
      # with the composite_primary_keys gem (it returns composite
      # primary key attribute names as hashes).
        record.attributes.select {|key| key.is_a?(String) }.each do |attribute, value|
          attribute_strings << dump_attribute_new(attribute, value, io, options) unless options[:exclude].include?(attribute.to_sym)
        end

      elsif record.class == BSON::ObjectId || record.class == Fixnum || record.class  == String
        # received an id element of a whole array of single record ids
          attribute = "_id"
          value = record
          attribute_strings << dump_attribute_new(attribute, value, io, options)

      else
        # use record.each directly for mongo internal documents
        record.each do |attribute, value|
          attribute_strings << dump_attribute_new(attribute, value, io, options) unless options[:exclude].include?(attribute.to_sym)
        end
      end

      open_character, close_character = options[:import] ? ['[', ']'] : ['{', '}']

      "#{open_character}#{attribute_strings.join(", ")}#{close_character}"
    end

    def dump_attribute_new(attribute, value, io, options)
      options[:import] ? value_to_s(value, io, options) : "#{attribute}: #{value_to_s(value, io, options)}"
    end

    def value_to_s(value, io, options)
      if value.class == BSON::ObjectId
        value = value.to_s
        value.inspect

      elsif value.class == Array
        buffer = open_io(file: false)
        write_records_to_io(value, buffer, options, false)

        value = buffer.string

      else
        value = case value
                when BigDecimal, IPAddr
                  value.to_s
                when Date, Time, DateTime
                  value.to_s(:db)
                when Range
                  range_to_string(value)
                else
                  value
                end

        value.inspect
      end

    end

    def range_to_string(object)
      from = object.begin.respond_to?(:infinite?) && object.begin.infinite? ? '' : object.begin
      to   = object.end.respond_to?(:infinite?) && object.end.infinite? ? '' : object.end
      "[#{from},#{to}#{object.exclude_end? ? ')' : ']'}"
    end

    def open_io(options)
      if options[:file].present?
        mode = options[:append] ? 'a+' : 'w+'

        File.open(options[:file], mode)
      else
        StringIO.new('', 'w+')
      end
    end

    def write_records_to_io(records, io, options, main)
      options[:exclude] ||= [:id, :created_at, :updated_at]

      if main
        method = options[:import] ? 'import' : 'create!'
        io.write("#{model_for(records)}.#{method}(")
        io.write("[\n  ")
      else
        io.write("[")
      end

      if options[:import]
        io.write("[#{attribute_names(records, options).map {|name| name.to_sym.inspect}.join(', ')}], ")
        io.write("[\n  ")
      end

      enumeration_method = if records.is_a?(ActiveRecord::Relation) || records.is_a?(Class)
                             :active_record_enumeration
                           else
                             :enumerable_enumeration
                           end

      send(enumeration_method, records, io, options) do |record_strings, last_batch|
        if main
        io.write(record_strings.join(",\n  "))
        else
        io.write(record_strings.join(",  "))
        end

        io.write(",\n  ") unless last_batch
      end

      if main
        io.write("\n])\n")
      else
        io.write("]")
      end

      if options[:file].present?
        nil
      else
        io.rewind
        io.read
      end
    end

    def attribute_names(records, options)
      attribute_names = if records.is_a?(ActiveRecord::Relation) || records.is_a?(Class)
                          records.attribute_names
                        else
                          records[0].attribute_names
                        end

      attribute_names.select {|name| !options[:exclude].include?(name.to_sym)}
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
