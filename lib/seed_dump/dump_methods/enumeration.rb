class SeedDump
  module DumpMethods
    module Enumeration
      def active_record_enumeration(records, _io, options)
        # If the records don't already have an order,
        # order them by primary key ascending.
        if !records.respond_to?(:arel) || records.arel.orders.blank?
          records.order("#{records.quoted_table_name}.#{records.quoted_primary_key} ASC")
        end

        num_of_batches, batch_size, last_batch_size = batch_params_from(records, options)

        processed_entities = 0
        # Loop through each batch
        (1..num_of_batches).each do |batch_number|
          record_strings = []

          last_batch = (batch_number == num_of_batches)

          cur_batch_size = if last_batch
                             last_batch_size
                           else
                             batch_size
                           end

          processed_entities += cur_batch_size

          # Loop through the records of the current batch
          records.offset((batch_number - 1) * batch_size).limit(cur_batch_size).each do |record|
            record_strings << dump_record(record, options)
          end

          should_split_file = split_file?(processed_entities, options)
          processed_entities -= options[:file_split_limit] if should_split_file

          yield record_strings, last_batch, should_split_file
        end
      end

      def split_file?(processed_entities, options)
        return false if options[:file_split_limit].nil?

        (processed_entities / file_index_from(options)) >= options[:file_split_limit]
      end

      def enumerable_enumeration(records, _io, options)
        num_of_batches, batch_size = batch_params_from(records, options)

        record_strings = []

        batch_number = 1

        records.each_with_index do |record, i|
          record_strings << dump_record(record, options)

          last_batch = (i == records.length - 1)

          next unless (record_strings.length == batch_size) || last_batch

          yield record_strings, last_batch

          record_strings = []
          batch_number += 1
        end
      end

      def batch_params_from(records, options)
        batch_size = batch_size_from(options)

        count = records.count

        remainder = count % batch_size

        [(count.to_f / batch_size).ceil, batch_size, (remainder.zero? ? batch_size : remainder)]
      end

      def batch_size_from(options)
        options[:batch_size]&.to_i || 1000
      end

      def file_index_from(options)
        options[:current_file_index]&.to_i || 1
      end
    end
  end
end
