class SeedDump
  module Environment

    def dump_using_environment(env = {})
      Rails.application.eager_load!

      mongo = env['MONGO'] == 'true'

      if mongo
        tables = Mongoid.default_session.collections
        mong = ""
        tables.each do |table|
          mong = mong + table.name + ","
        end
        models_env = env['MODEL'] || env['MODELS'] || mong
      else
        models_env = env['MODEL'] || env['MODELS']
      end

      models_with_empties = if models_env
                 models_env.split(',')
                           .collect do |x|
                              y = x.strip.underscore.singularize.camelize
                              begin
                                y.constantize
                              rescue NameError => err
                                #TODO: raise a warning that this x model isn't constantizeable ... will be skipped
                              end
                           end
               else
                 ActiveRecord::Base.descendants
               end

      # reject nils that represent the constanized models
      models = models_with_empties.reject { |c| c == nil}

      if mongo
        models = models.select do |model|
                   (model.to_s != 'ActiveRecord::SchemaMigration') && \
                    model.exists?
                 end
      else
        models = models.select do |model|
                   (model.to_s != 'ActiveRecord::SchemaMigration') && \
                    model.table_exists? && \
                    model.exists?
                 end
      end

      append = (env['APPEND'] == 'true')

      models_exclude_env = env['MODELS_EXCLUDE']
      if models_exclude_env
        models_exclude_env.split(',')
                          .collect do |x|
                                y = x.strip.underscore.singularize.camelize
                              begin
                                y.constantize
                              rescue NameError => err
                                #TODO: raise a warning
                              end
                            end
                          .each { |exclude| models.delete(exclude) }
      end

      models.each do |model|
        model = model.limit(env['LIMIT'].to_i) if env['LIMIT']

        SeedDump.dump(model,
                      append: append,
                      batch_size: (env['BATCH_SIZE'] ? env['BATCH_SIZE'].to_i : nil),
                      exclude: (env['EXCLUDE'] ? env['EXCLUDE'].split(',').map {|e| e.strip.to_sym} : nil),
                      file: (env['FILE'] || 'db/seeds.rb'),
                      import: (env['IMPORT'] == 'true'),
                      mongo: mongo)

        append = true
      end
    end
  end
end
