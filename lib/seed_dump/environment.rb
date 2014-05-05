class SeedDump
  module Environment

    def dump_using_environment(env = {})
      Rails.application.eager_load! if defined?(Rails)

      models = if env['MODEL'] || env['MODELS']
                 (env['MODEL'] || env['MODELS']).split(',').collect {|x| x.strip.underscore.singularize.camelize.constantize }
               else
                 ActiveRecord::Base.descendants.select do |model|
                   (model.to_s != 'ActiveRecord::SchemaMigration') && \
                    model.table_exists? && \
                    model.exists?
                 end
               end

      append = (env['APPEND'] == 'true')

      models.each do |model|
        model = model.limit(env['LIMIT'].to_i) if env['LIMIT']

        SeedDump.dump(model,
                      append: append,
                      batch_size: (env['BATCH_SIZE'] ? env['BATCH_SIZE'].to_i : nil),
                      exclude: (env['EXCLUDE'] ? env['EXCLUDE'].split(',').map {|e| e.strip.to_sym} : nil),
                      file: (env['FILE'] || 'db/seeds.rb'),
                      use_import: %w(true t 1).include?(env['USE_IMPORT']), # default is false
                      validate: !%w(false f 0).include?(env['VALIDATE'])) # default is true

        append = true
      end
    end
  end
end
