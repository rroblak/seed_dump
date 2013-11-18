class SeedDump
  module ConsoleMethods
    module Enumeration
      def active_record_enumeration(records, io, options)
        # If the records don't already have an order,
        # order them by primary key ascending.
        if !records.respond_to?(:arel) || records.arel.orders.blank?
          records.order("#{records.quoted_table_name}.#{records.quoted_primary_key} ASC")
        end

        batch_size, last_batch_number = batch_params_from(records, options)

        # Loop through each batch
        (1..last_batch_number).each do |batch_number|

          record_strings = []

          # Loop through the records of the current batch
          records.offset((batch_number - 1) * batch_size).limit(batch_size).each do |record|
            record_strings << dump_record(record)
          end

          yield record_strings, batch_number, last_batch_number
        end
      end

      def enumerable_enumeration(records, io, options)
        batch_size, last_batch_number = batch_params_from(records, options)

        record_strings = []

        batch_number = 1

        records.each_with_index do |record, i|
          record_strings << dump_record(record)

          if (record_strings.length == batch_size) || (i == records.length - 1)
            yield record_strings, batch_number, last_batch_number

            record_strings = []
            batch_number += 1
          end
        end
      end

      def batch_params_from(records, options)
        batch_size = batch_size_from(options)

        last_batch_number = (records.count.to_f / batch_size).ceil

        [batch_size, last_batch_number]
      end

      def batch_size_from(options)
        if options[:batch_size].present?
          options[:batch_size].to_i
        else
          1000
        end
      end
    end
  end
end
