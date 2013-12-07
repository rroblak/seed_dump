class SeedDump
  module Environment

    def dump_using_environment(env = {})
      Rails.application.eager_load!

      models = if env['MODELS']
                 env['MODELS'].split(',').collect {|x| x.strip.underscore.singularize.camelize.constantize }
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
                      create_method: env['CREATE_METHOD'],
                      exclude_attributes: (env['EXCLUDE'] ? env['EXCLUDE'].split(',').map {|e| e.strip.to_sym} : nil),
                      file: (env['FILE'] || 'db/seeds.rb'))

        append = true
      end
    end
  end
end

