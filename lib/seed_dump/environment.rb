class SeedDump
  module Environment

    def dump_using_environment(env = {})
      Rails.application.eager_load!

      models = retrieve_models(env) - retrieve_models_exclude(env)

      global_limit = retrieve_limit_value(env)
      model_limits = retrieve_model_limits_value(env)
      append = retrieve_append_value(env)
      models.each do |model|
        # Determine the limit to apply for this model:
        # 1. Check MODEL_LIMITS for a per-model override
        # 2. Fall back to global LIMIT
        # 3. If neither, no limit is applied
        limit = limit_for_model(model, model_limits, global_limit)
        model = model.limit(limit) if limit.present?

        SeedDump.dump(model,
                      append: append,
                      batch_size: retrieve_batch_size_value(env),
                      exclude: retrieve_exclude_value(env),
                      file: retrieve_file_value(env),
                      import: retrieve_import_value(env),
                      insert_all: retrieve_insert_all_value(env))

        append = true # Always append for every model after the first
                      # (append for the first model is determined by
                      # the APPEND environment variable).
      end
    end

    private
    # Internal: Array of Strings corresponding to Active Record model class names
    # that should be excluded from the dump.
    ACTIVE_RECORD_INTERNAL_MODELS = ['ActiveRecord::SchemaMigration',
                                     'ActiveRecord::InternalMetadata']

    # Internal: Retrieves an Array of Active Record model class constants to be
    # dumped.
    #
    # If a "MODEL" or "MODELS" environment variable is specified, there will be
    # an attempt to parse the environment variable String by splitting it on
    # commmas and then converting it to constant.
    #
    # Model classes that do not have corresponding database tables or database
    # records will be filtered out, as will model classes internal to Active
    # Record.
    #
    # env - Hash of environment variables from which to parse Active Record
    #       model classes. The Hash is not optional but the "MODEL" and "MODELS"
    #       keys are optional.
    #
    # Returns the Array of Active Record model classes to be dumped.
    def retrieve_models(env)
      # Parse either the "MODEL" environment variable or the "MODELS"
      # environment variable, with "MODEL" taking precedence.
      models_env = env['MODEL'] || env['MODELS']

      # If there was a use models environment variable, split it and
      # convert the given model string (e.g. "User") to an actual
      # model constant (e.g. User).
      #
      # If a models environment variable was not given, use descendants of
      # ActiveRecord::Base as the target set of models. This should be all
      # model classes in the project.
      models = if models_env
                 models_env.split(',')
                           .collect {|x| x.strip.underscore.singularize.camelize.constantize }
               else
                 ActiveRecord::Base.descendants
               end


      # Filter the set of models to exclude:
      #   - The ActiveRecord::SchemaMigration model which is internal to Rails
      #     and should not be part of the dumped data.
      #   - Classes that don't respond to table_exists? or exists? (e.g., abstract
      #     classes or non-model descendants of ActiveRecord::Base).
      #   - Models that don't have a corresponding table in the database.
      #   - Models whose corresponding database tables are empty.
      filtered_models = models.select do |model|
                          begin
                            !ACTIVE_RECORD_INTERNAL_MODELS.include?(model.to_s) && \
                            model.table_exists? && \
                            model.exists?
                          rescue NoMethodError
                            # Skip classes that don't properly respond to table_exists? or exists?
                            # This can happen with abstract classes or other non-model descendants
                            false
                          end
                        end

      # Deduplicate HABTM models that share the same table (issues #26, #114).
      # Rails creates two auto-generated models for each HABTM association
      # (e.g., User::HABTM_Roles and Role::HABTM_Users) that both point to
      # the same join table. We only want to dump one of them.
      deduplicate_habtm_models(filtered_models)
    end

    # Internal: Deduplicates HABTM models that share the same table.
    #
    # When using has_and_belongs_to_many, Rails creates auto-generated models
    # like User::HABTM_Roles and Role::HABTM_Users that both reference the same
    # join table. Without deduplication, the join table data would be dumped twice.
    #
    # models - Array of ActiveRecord model classes.
    #
    # Returns the Array with duplicate HABTM models removed.
    def deduplicate_habtm_models(models)
      habtm, non_habtm = models.partition { |m| m.to_s.include?('HABTM_') }
      non_habtm + habtm.uniq(&:table_name)
    end

    # Internal: Returns a Boolean indicating whether the value for the "APPEND"
    # key in the given Hash is equal to the String "true" (ignoring case),
    # false if no value exists.
    def retrieve_append_value(env)
      parse_boolean_value(env['APPEND'])
    end

    # Internal: Returns a Boolean indicating whether the value for the "IMPORT"
    # key in the given Hash is equal to the String "true" (ignoring case),
    # false if  no value exists.
    def retrieve_import_value(env)
      parse_boolean_value(env['IMPORT'])
    end

    # Internal: Returns a Boolean indicating whether the value for the "INSERT_ALL"
    # key in the given Hash is equal to the String "true" (ignoring case),
    # false if no value exists. INSERT_ALL uses Rails 6+ insert_all for faster
    # bulk inserts that bypass validations and callbacks.
    def retrieve_insert_all_value(env)
      parse_boolean_value(env['INSERT_ALL'])
    end

    # Internal: Retrieves an Array of Class constants parsed from the value for
    # the "MODELS_EXCLUDE" key in the given Hash, and an empty Array if such
    # key exists.
    def retrieve_models_exclude(env)
      env['MODELS_EXCLUDE'].to_s
                           .split(',')
                           .collect { |x| x.strip.underscore.singularize.camelize.constantize }
    end

    # Internal: Retrieves an Integer from the value for the "LIMIT" key in the
    # given Hash, and nil if no such key exists.
    def retrieve_limit_value(env)
      retrieve_integer_value('LIMIT', env)
    end

    # Internal: Parses the MODEL_LIMITS environment variable into a Hash.
    #
    # MODEL_LIMITS allows per-model limit overrides to prevent LIMIT from
    # breaking associations (issue #142). Format: "Model1:limit1,Model2:limit2"
    #
    # A limit of 0 means "unlimited" (dump all records for that model).
    #
    # Example: MODEL_LIMITS="Teacher:0,Student:50"
    #   - Teacher: dumps all records (0 = unlimited)
    #   - Student: dumps 50 records
    #   - Other models: fall back to global LIMIT or dump all if no LIMIT set
    #
    # env - Hash of environment variables.
    #
    # Returns a Hash mapping model names (String) to limits (Integer), or
    # empty Hash if MODEL_LIMITS is not set.
    def retrieve_model_limits_value(env)
      return {} unless env['MODEL_LIMITS']

      env['MODEL_LIMITS'].split(',').each_with_object({}) do |pair, hash|
        model_name, limit = pair.split(':').map(&:strip)
        hash[model_name] = limit.to_i if model_name && limit
      end
    end

    # Internal: Determines the limit to apply for a given model.
    #
    # Precedence:
    # 1. Per-model limit from MODEL_LIMITS (0 means unlimited)
    # 2. Global LIMIT
    # 3. nil (no limit, dump all records)
    #
    # model - The ActiveRecord model class.
    # model_limits - Hash of per-model limits from MODEL_LIMITS.
    # global_limit - The global LIMIT value (Integer or nil).
    #
    # Returns an Integer limit or nil if no limit should be applied.
    def limit_for_model(model, model_limits, global_limit)
      model_name = model.to_s

      if model_limits.key?(model_name)
        limit = model_limits[model_name]
        # 0 means unlimited - return nil to skip applying limit
        limit == 0 ? nil : limit
      else
        global_limit
      end
    end

    # Internal: Retrieves an Array of Symbols from the value for the "EXCLUDE"
    # key from the given Hash, and nil if no such key exists.
    #
    # If INCLUDE_ALL is set to 'true', returns an empty array to disable
    # the default exclusion of id, created_at, updated_at columns. This provides
    # a cleaner alternative to EXCLUDE="" (issue #147).
    #
    # Note that explicit EXCLUDE values take precedence over INCLUDE_ALL.
    def retrieve_exclude_value(env)
      if env['EXCLUDE']
        env['EXCLUDE'].split(',').map { |e| e.strip.to_sym }
      elsif parse_boolean_value(env['INCLUDE_ALL'])
        []
      else
        nil
      end
    end

    # Internal: Retrieves the value for the "FILE" key from the given Hash, and
    # 'db/seeds.rb' if no such key exists.
    def retrieve_file_value(env)
      env['FILE'] || 'db/seeds.rb'
    end

    # Internal: Retrieves an Integer from the value for the "BATCH_SIZE" key in
    # the given Hash, and nil if no such key exists.
    def retrieve_batch_size_value(env)
      retrieve_integer_value('BATCH_SIZE', env)
    end

    # Internal: Retrieves an Integer from the value for the given key in
    # the given Hash, and nil if no such key exists.
    def retrieve_integer_value(key, hash)
      hash[key] ? hash[key].to_i : nil
    end

    # Internal: Parses a Boolean from the given value.
    def parse_boolean_value(value)
      value.to_s.downcase == 'true'
    end
  end
end
