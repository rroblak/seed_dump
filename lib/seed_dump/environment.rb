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

      # Orders the models to avoid conflicts with foreign keys
      i = 0
      repetition = 0  #To avoid an infinite loop if there are circular relations
      while i < models.length
        model = models[i]
        reflections = model.reflections
        foreign_key_klasses = reflections.collect{|a, b| b.klass if b.macro==:belongs_to && !%w(creator updater).include?(a)}
        index = i
        switched = false
        foreign_key_klasses.each do |klass|
          foreign_key_index = models.index(klass)
          if !foreign_key_index.nil? && foreign_key_index > index
            models[index], models[foreign_key_index] = models[foreign_key_index], models[index]
            index = foreign_key_index
            switched = true
          end
        end
        if !switched || repetition == models.length
          i += 1
          repetition = 0
        else
          repetition += 1
        end
      end

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
