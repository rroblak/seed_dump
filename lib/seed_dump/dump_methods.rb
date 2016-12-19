class SeedDump
  module DumpMethods
    include Enumeration

    def dump(records, options = {})
      return nil if records.count == 0

      io = open_io(options)

      write_records_to_io(records, io, options)

      ensure
        io.close if io.present?
    end

    private

    def dump_record(record, options)
      attribute_strings = []
      variable_name = record.class.name.downcase + record.id.to_s
      attribute_strings << "#{record.class.name.downcase}#{record.id} = #{record.class.name}.new"

      # We select only string attribute names to avoid conflict
      # with the composite_primary_keys gem (it returns composite
      # primary key attribute names as hashes).
      record.attributes.select {|key| key.is_a?(String) }.each do |attribute, value|
        attribute_strings << dump_attribute_new(attribute, value, variable_name, options) unless options[:exclude].include?(attribute.to_sym)
      end
      attribute_strings << "#{record.class.name}.import([#{variable_name}], :validate => false);\n"

      "#{attribute_strings.join("; ")}"
    end

    def dump_attribute_new(record, attribute, value, variable_name, options)
      if options[:import]
        value_to_s(value)
      else
        if record.send(attribute).class.ancestors.include?(Cloudinary::CarrierWave)
          "#{variable_name}.write_attribute(:#{attribute} ,#{value_to_s(value)})"
        else
          "#{variable_name}.try(:#{attribute}=, #{value_to_s(value)})"
        end
      end
    end

    def value_to_s(value)
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

    def write_records_to_io(records, io, options)
      options[:exclude] ||= []
      method = options[:import] ? 'import' : 'new'
      if options[:import]
        io.write("[#{attribute_names(records, options).map {|name| name.to_sym.inspect}.join(', ')}], ")
      end
      enumeration_method = if records.is_a?(ActiveRecord::Relation) || records.is_a?(Class)
                             :active_record_enumeration
                           else
                             :enumerable_enumeration
                           end

      send(enumeration_method, records, io, options) do |record_strings, last_batch|
        io.write(record_strings.join(";\n  "))

        io.write(";\n  ") unless last_batch
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
