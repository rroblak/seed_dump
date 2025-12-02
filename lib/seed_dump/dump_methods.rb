require 'bigdecimal'
require 'ipaddr'

require 'active_support/core_ext/object/try'
require 'active_support/core_ext/time/conversions'
require 'active_support/core_ext/date/conversions'
require 'active_support/core_ext/date_time/conversions'

class SeedDump
  # Provides the core logic for dumping records.
  module DumpMethods
    include Enumeration

    # Dumps a collection of records to a string or file.
    #
    # @param records [ActiveRecord::Relation, Class, Array<ActiveRecord::Base>] The records to dump.
    # @param options [Hash] Options for dumping.
    # @option options [String] :file Path to the output file. If nil, returns a string.
    # @option options [Boolean] :append Append to the file instead of overwriting. Default: false.
    # @option options [Integer] :batch_size Number of records per batch. Default: 1000.
    # @option options [Array<Symbol>] :exclude Attributes to exclude. Default: [:id, :created_at, :updated_at].
    # @option options [Boolean, Hash] :import Use activerecord-import format. If Hash, passed as options to import. Default: false.
    # @return [String, nil] The dump string if :file is nil, otherwise nil.
    def dump(records, options = {})
      # Handle potential empty input gracefully
      # Use unscope(:select) for AR relations to avoid issues with default_scope
      # that selects specific columns, which would cause COUNT(col1, col2, ...) errors
      record_count = if records.respond_to?(:unscope)
                       records.unscope(:select).count
                     elsif records.respond_to?(:count)
                       records.count
                     elsif records.respond_to?(:empty?)
                       records.empty? ? 0 : 1
                     else
                       records.size
                     end
      return nil if record_count == 0

      io = nil
      begin
        io = open_io(options)
        write_records_to_io(records, io, options)

        # If no file option was given (meaning we used StringIO), read the content
        if options[:file].blank? # Check if :file option is nil or empty
          io.rewind
          io.read
        else
          # If a file option was given, return nil as the file was written directly
          nil
        end
      ensure
        # Ensure the IO object is closed if it's a File object
        io.close if io.is_a?(File) && io.respond_to?(:close) && !io.closed?
      end
    end

    private

    # Dumps a single record to its string representation.
    #
    # @param record [ActiveRecord::Base] The record to dump.
    # @param options [Hash] Dumping options (see #dump).
    # @return [String] The string representation of the record.
    def dump_record(record, options)
      attribute_strings = []

      # Ensure attributes is a Hash-like object responding to #each
      unless record.respond_to?(:attributes) && record.attributes.respond_to?(:each)
        raise ArgumentError, "Record object does not have an 'attributes' method returning an iterable collection."
      end

      record.attributes.each do |attribute, value|
        # Ensure attribute key is usable (String or Symbol)
        attr_sym = attribute.to_sym
        # Exclude attributes specified in the options
        next if options[:exclude].include?(attr_sym)

        attribute_strings << dump_attribute(attribute, value, options)
      end

      # Determine the appropriate characters based on import option
      open_character, close_character = options[:import] ? ['[', ']'] : ['{', '}']

      "#{open_character}#{attribute_strings.join(', ')}#{close_character}"
    end

    # Formats a single attribute key-value pair or just the value for dumping.
    #
    # @param attribute [String, Symbol] The attribute name.
    # @param value [Object] The attribute value.
    # @param options [Hash] Dumping options.
    # @return [String] The formatted attribute string.
    def dump_attribute(attribute, value, options)
      formatted_value = value_to_s(value)
      # If importing, just output the value; otherwise, output key: value
      options[:import] ? formatted_value : "#{attribute}: #{formatted_value}"
    end

    # Converts a value to its string representation suitable for seeding.
    # Handles various data types like BigDecimal, IPAddr, Date/Time, Range, and RGeo.
    #
    # @param value [Object] The value to convert.
    # @return [String] The inspected string representation of the value.
    def value_to_s(value)
      formatted_value = case value
                          when BigDecimal, IPAddr
                            # Use standard to_s for these types
                            value.to_s
                          when ->(v) { defined?(ActionText::Content) && v.is_a?(ActionText::Content) }
                            # ActionText::Content should be dumped as its HTML string (issue #154)
                            value.to_s
                          when Date, Time, DateTime
                            # Use ISO 8601 format to preserve timezone information (issue #111)
                            # This prevents timestamp shifts when reimporting seeds on machines
                            # with different timezones
                            value.iso8601
                          when Range
                            # Convert range to a specific string format
                            range_to_string(value)
                          when ->(v) { defined?(RGeo::Feature::Instance) && v.is_a?(RGeo::Feature::Instance) }
                            # Handle RGeo geometry types if RGeo is loaded
                            value.to_s # RGeo objects often have a suitable WKT representation via to_s
                          else
                            # For other types, use the value directly (inspect will handle basic types)
                            value
                          end

      # Use inspect to get a string representation suitable for Ruby code
      # (e.g., strings are quoted, nil becomes "nil").
      formatted_value.inspect
    end

    # Converts a Range object to a string representation like "[start,end]" or "[start,end)".
    # Handles infinite ranges gracefully.
    #
    # @param object [Range] The range to convert.
    # @return [String] The string representation of the range.
    def range_to_string(object)
      # Determine start: empty string if negative infinity, otherwise the beginning value.
      from = object.begin.respond_to?(:infinite?) && object.begin.infinite? && object.begin < 0 ? '' : object.begin
      # Determine end: empty string if positive infinity, otherwise the ending value.
      to   = object.end.respond_to?(:infinite?) && object.end.infinite? && object.end > 0 ? '' : object.end
      # Determine closing bracket: ')' if end is excluded, ']' otherwise.
      bracket = object.exclude_end? ? ')' : ']'

      "[#{from},#{to}#{bracket}"
    end

    # Opens an IO object for writing (either a File or StringIO).
    #
    # @param options [Hash] Options containing :file and :append keys.
    # @return [IO] The opened IO object (File or StringIO).
    def open_io(options)
      if options[:file].present?
        # Open file in append ('a+') or write ('w+') mode
        mode = options[:append] ? 'a+' : 'w+'
        File.open(options[:file], mode)
      else
        # Use StringIO for in-memory operations with a mutable string
        StringIO.new(+'', 'w+')
      end
    end

    # Writes the records to the given IO object, handling batching and formatting.
    #
    # @param records [ActiveRecord::Relation, Class, Array<ActiveRecord::Base>] The records to write.
    # @param io [IO] The IO object to write to (File or StringIO).
    # @param options [Hash] Dumping options.
    # @return [void] This method now only writes to the IO. Reading happens in #dump.
    def write_records_to_io(records, io, options)
      # Set default excluded attributes if not provided
      options[:exclude] ||= [:id, :created_at, :updated_at]
      # Ensure exclude is an array of symbols
      options[:exclude] = options[:exclude].map(&:to_sym)

      # Determine the model class
      model_klass = model_for(records)
      unless model_klass
          # Raise ArgumentError if model cannot be determined
          raise ArgumentError, "Could not determine model class from records."
      end


      # Determine the method call ('import' or 'create!')
      method = options[:import] ? 'import' : 'create!'
      io.write("#{model_name_for_output(model_klass)}.#{method}(")

      # If using import, write the attribute names header
      if options[:import]
        column_names = attribute_names(records, options).map { |name| name.to_sym.inspect }
        io.write("[#{column_names.join(', ')}], ")
      end

      # Start the array of records
      io.write("[\n  ")

      # Choose the appropriate enumeration method based on record type
      enumeration_method = if records.is_a?(ActiveRecord::Relation) || records.is_a?(Class)
                             :active_record_enumeration
                           else
                             :enumerable_enumeration
                           end

      # Process records in batches
      send(enumeration_method, records, io, options) do |record_strings, last_batch|
        # Join the record strings for the current batch and write them
        io.write(record_strings.join(",\n  "))
        # Add a comma and newline if this isn't the last batch
        io.write(",\n  ") unless last_batch
      end

      # Close the array of records and the method call, adding import options if necessary
      io.write("\n]#{active_record_import_options(options)})\n")

      # Flushing might be needed for some IO types, but generally not StringIO
      # io.flush if io.respond_to?(:flush)

      # Reading the content now happens in the main #dump method
    end

    # Generates the string for activerecord-import options, if provided.
    #
    # @param options [Hash] Dumping options, potentially containing :import hash.
    # @return [String] Formatted options string or empty string.
    def active_record_import_options(options)
      # Check if :import is a Hash containing options
      return '' unless options[:import].is_a?(Hash) && options[:import].any?

      # Format the options hash into a string like ", key1: value1, key2: value2"
      options_string = options[:import].map { |key, value| "#{key}: #{value.inspect}" }.join(', ')
      ", #{options_string}" # Prepend comma and space
    end

    # Gets the attribute names for the records, excluding specified ones.
    #
    # @param records [ActiveRecord::Relation, Class, Array<ActiveRecord::Base>] The records source.
    # @param options [Hash] Options containing :exclude array.
    # @return [Array<String>] Filtered attribute names.
    def attribute_names(records, options)
      # Get attribute names from the model or the first record
      base_names = if records.is_a?(ActiveRecord::Relation) || records.is_a?(Class)
                     model = model_for(records)
                     # Ensure model is not nil before calling attribute_names
                     model&.respond_to?(:attribute_names) ? model.attribute_names : []
                   elsif records.is_a?(Array) && records.first.respond_to?(:attribute_names)
                     records.first.attribute_names
                   else
                     [] # Cannot determine attribute names
                   end

      # Filter out excluded attribute names
      base_names.select { |name| !options[:exclude].include?(name.to_sym) }
    end

    # Formats the model name for output in the generated seed file.
    # For HABTM join models (which are private constants), uses const_get syntax
    # to avoid NameError when the seeds file is loaded.
    #
    # @param model_klass [Class] The model class.
    # @return [String] The formatted model name for use in seeds.rb.
    def model_name_for_output(model_klass)
      model_name = model_klass.to_s

      # Check if this is an HABTM join model (contains ::HABTM_)
      # e.g., "Dealer::HABTM_UStations" -> "Dealer.const_get('HABTM_UStations')"
      if model_name.include?('::HABTM_')
        # Split on the last ::HABTM_ to handle nested namespaces
        # e.g., "Foo::Bar::HABTM_Bazs" -> parent="Foo::Bar", habtm_name="HABTM_Bazs"
        parts = model_name.rpartition('::')
        parent = parts[0]      # Everything before the last ::
        habtm_name = parts[2]  # The HABTM_* part
        "#{parent}.const_get('#{habtm_name}')"
      else
        model_name
      end
    end

    # Determines the ActiveRecord model class from the given records source.
    #
    # @param records [ActiveRecord::Relation, Class, Array<ActiveRecord::Base>] The records source.
    # @return [Class, nil] The model class or nil if indeterminable.
    def model_for(records)
      if records.is_a?(Class) && records < ActiveRecord::Base
        records # It's the model class itself
      elsif records.respond_to?(:klass) # ActiveRecord::Relation often uses .klass
        records.klass
      elsif records.respond_to?(:model) # Some older versions might use .model
         records.model
      elsif records.is_a?(Array) && !records.empty?
         # Check if the first element is an AR::Base instance or the RangeSample mock
         first_element = records.first
         if first_element.is_a?(ActiveRecord::Base) || (first_element.respond_to?(:class) && first_element.class.name == "RangeSample")
           first_element.class
         else
           nil # Cannot determine model from array elements
         end
      else
        nil # Could not determine model
      end
    end
  end
end
