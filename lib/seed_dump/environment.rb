class SeedDump
  module Environment

    def dump_using_environment(env = {})
      Rails.application.eager_load!

      models_env = env['MODEL'] || env['MODELS']
      models = if models_env
                 models_env.split(',')
                           .collect {|x| x.strip.underscore.singularize.camelize.constantize }
               else
                 ActiveRecord::Base.descendants
               end

      models = models.select do |model|
                 (model.to_s != 'ActiveRecord::SchemaMigration') && \
                  model.table_exists? && \
                  model.exists?
               end

      append = (env['APPEND'] == 'true')

      models_exclude_env = env['MODELS_EXCLUDE']
      if models_exclude_env
        models_exclude_env.split(',')
                          .collect {|x| x.strip.underscore.singularize.camelize.constantize }
                          .each { |exclude| models.delete(exclude) }
      end


      # Eliminate HABTM models that have the same underlying table; otherwise 
      # they'll be dumped twice, once in each direction. Probably should apply
      # to all models, but it's possible there are edge cases in which this 
      # is not the right behavior.

      habtm, non_habtm = models.partition {|m| m.name =~ /^HABTM_/}
      models = non_habtm + habtm.uniq { |m| m.table_name }

      models.each do |model|
        model = model.limit(env['LIMIT'].to_i) if env['LIMIT']

        SeedDump.dump(model,
                      append: append,
                      batch_size: (env['BATCH_SIZE'] ? env['BATCH_SIZE'].to_i : nil),
                      exclude: (env['EXCLUDE'] ? env['EXCLUDE'].split(',').map {|e| e.strip.to_sym} : nil),
                      file: (env['FILE'] || 'db/seeds.rb'),
                      import: (env['IMPORT'] == 'true'))

        append = true
      end
    end
  end
end
