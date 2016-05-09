require 'tsort'

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

      # Sort models in dependency order to accommodate foreign key checks or validations.
      # Based on code by Ryan Stenberg
      # https://www.viget.com/articles/identifying-foreign-key-dependencies-from-activerecordbase-classes

      dependencies = models.map do |model|
        associations = model.reflect_on_all_associations(:belongs_to)
        referents = associations.map do |association|
          if association.options[:polymorphic]
            ActiveRecord::Base.descendants.select do |other_model|
              other_model.reflect_on_all_associations(:has_many).any? do |has_many_association|
                has_many_association.options[:as] == association.name
              end
            end
          else
            association.klass
          end
        end
        [ model, referents.flatten ]
      end
      models = TSortableHash[*dependencies.flatten(1)].tsort

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

    class TSortableHash < Hash
      include TSort
      alias tsort_each_node each_key
      def tsort_each_child(node, &block)
        fetch(node).each(&block)
      end
    end      

  end
end

