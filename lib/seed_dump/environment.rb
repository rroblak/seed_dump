class SeedDump
  module Environment

    def dump_using_environment(env = {})
      Rails.application.eager_load!

      models = retrieve_models(env) - retrieve_models_exclude(env)

      # Sort models by foreign key dependencies (issues #78, #83)
      # This ensures models are dumped in the correct order so that
      # seeds can be imported without foreign key violations.
      models = sort_models_by_dependencies(models)

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
                      group_sti_by_class: retrieve_group_sti_by_class_value(env),
                      header: retrieve_header_value(env),
                      import: retrieve_import_value(env),
                      insert_all: retrieve_insert_all_value(env),
                      upsert_all: retrieve_upsert_all_value(env))

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
                           .collect {|x| model_name_to_constant(x.strip) }
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
      deduped_habtm = deduplicate_habtm_models(filtered_models)

      # Deduplicate STI models that share the same table (issue #120).
      # With STI, subclasses (e.g., AdminUser < User) share the same table as
      # their parent. We only want to dump the base class, which will include
      # all records including subclass records with proper type discrimination.
      deduplicate_sti_models(deduped_habtm)
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

    # Internal: Deduplicates STI models that share the same table.
    #
    # With Single Table Inheritance, subclasses like AdminUser < User share the
    # same database table as their parent. Without deduplication, each STI class
    # would be dumped separately, creating duplicate records.
    #
    # The solution is to keep only the base class for each STI hierarchy, which
    # will include all records (base and subclass) with proper type discrimination.
    #
    # models - Array of ActiveRecord model classes.
    #
    # Returns the Array with STI subclasses removed (only base classes kept).
    def deduplicate_sti_models(models)
      models.select do |model|
        # Keep the model only if it IS its own base class
        # For STI subclasses, base_class returns the parent (e.g., AdminUser.base_class => User)
        # For non-STI models, base_class returns self
        model.base_class == model
      end
    end

    # Internal: Sorts models by foreign key dependencies using topological sort.
    #
    # Models with foreign keys (belongs_to associations) depend on the models
    # they reference. This method ensures that referenced models are dumped
    # before the models that depend on them, preventing foreign key violations
    # when importing seeds (issues #78, #83).
    #
    # For example, if Book belongs_to Author, Author will be sorted before Book.
    #
    # Uses Kahn's algorithm for topological sorting. If there are circular
    # dependencies, the remaining models are appended in their original order.
    #
    # models - Array of ActiveRecord model classes to sort.
    #
    # Returns a new Array with models sorted by dependencies (dependencies first).
    def sort_models_by_dependencies(models)
      return models if models.empty?

      # Build a lookup for models by table name for faster dependency resolution
      model_by_table = models.each_with_object({}) do |model, hash|
        hash[model.table_name] = model
      end

      # Build dependency graph: model -> models it depends on (via belongs_to)
      dependencies = {}
      models.each do |model|
        dependencies[model] = find_model_dependencies(model, model_by_table)
      end

      # Topological sort using Kahn's algorithm
      topological_sort(models, dependencies)
    end

    # Internal: Finds the models that a given model depends on via belongs_to.
    #
    # model - The ActiveRecord model class to find dependencies for.
    # model_by_table - Hash mapping table names to model classes.
    #
    # Returns an Array of model classes that this model depends on.
    def find_model_dependencies(model, model_by_table)
      deps = []

      # Check belongs_to associations for foreign key dependencies
      model.reflect_on_all_associations(:belongs_to).each do |assoc|
        # Get the table name this association points to
        # Use the association's class_name if available, otherwise infer from name
        begin
          referenced_class = assoc.klass
          referenced_table = referenced_class.table_name

          # Only add as dependency if it's in our set of models to dump
          if model_by_table.key?(referenced_table)
            dep_model = model_by_table[referenced_table]
            deps << dep_model unless dep_model == model
          end
        rescue NameError, ArgumentError
          # Skip if we can't resolve the class (e.g., polymorphic without type)
          next
        end
      end

      deps.uniq
    end

    # Internal: Performs topological sort on models based on their dependencies.
    #
    # Uses Kahn's algorithm:
    # 1. Find all models with no dependencies (no incoming edges)
    # 2. Add them to the result and remove them from the graph
    # 3. Repeat until all models are sorted or a cycle is detected
    #
    # models - Array of model classes.
    # dependencies - Hash mapping each model to its dependencies.
    #
    # Returns an Array of models in topologically sorted order.
    def topological_sort(models, dependencies)
      result = []
      remaining = models.dup

      # Calculate in-degree (number of models depending on each model)
      # We need to track which models are "ready" (all their dependencies satisfied)
      while remaining.any?
        # Find models whose dependencies have all been processed
        ready = remaining.select do |model|
          dependencies[model].all? { |dep| result.include?(dep) }
        end

        if ready.empty?
          # Circular dependency detected - add remaining in original order
          result.concat(remaining)
          break
        end

        # Add ready models to result (maintain relative order for stability)
        ready.each do |model|
          result << model
          remaining.delete(model)
        end
      end

      result
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

    # Internal: Returns a Boolean indicating whether the value for the "UPSERT_ALL"
    # key in the given Hash is equal to the String "true" (ignoring case),
    # false if no value exists. UPSERT_ALL uses Rails 6+ upsert_all to preserve
    # original record IDs, which fixes foreign key reference issues when parent
    # records have been deleted (issue #104).
    def retrieve_upsert_all_value(env)
      parse_boolean_value(env['UPSERT_ALL'])
    end

    # Internal: Returns a Boolean indicating whether the value for the "HEADER"
    # key in the given Hash is equal to the String "true" (ignoring case),
    # false if no value exists. HEADER adds a comment at the top of the seed file
    # showing when and how it was generated for traceability (issue #126).
    def retrieve_header_value(env)
      parse_boolean_value(env['HEADER'])
    end

    # Internal: Returns a Boolean indicating whether the value for the "GROUP_STI_BY_CLASS"
    # key in the given Hash is equal to the String "true" (ignoring case),
    # false if no value exists. GROUP_STI_BY_CLASS groups STI records by their actual
    # class instead of base_class to fix enum issues (issue #170).
    def retrieve_group_sti_by_class_value(env)
      parse_boolean_value(env['GROUP_STI_BY_CLASS'])
    end

    # Internal: Retrieves an Array of Class constants parsed from the value for
    # the "MODELS_EXCLUDE" key in the given Hash, and an empty Array if such
    # key exists.
    def retrieve_models_exclude(env)
      env['MODELS_EXCLUDE'].to_s
                           .split(',')
                           .collect { |x| model_name_to_constant(x.strip) }
    end

    # Internal: Converts a model name string to a constant.
    #
    # This method handles the issue where model names ending in 's' (like "Boss")
    # were incorrectly singularized to "Bos" by older Rails versions (issue #121).
    #
    # The strategy is:
    # 1. Try camelized form first (handles "Boss", "boss", "user_profile")
    # 2. Fall back to underscore.singularize.camelize for plural table names
    #
    # model_name - String name of the model (e.g., "Boss", "boss", "users")
    #
    # Returns the Class constant for the model.
    # Raises NameError if the model cannot be found.
    def model_name_to_constant(model_name)
      # First, try the camelized version directly
      # This handles: "Boss" -> Boss, "boss" -> Boss, "user_profile" -> UserProfile
      camelized = model_name.camelize
      begin
        return camelized.constantize
      rescue NameError
        # Fall through to try singularized version
      end

      # Fall back to traditional approach for plural names
      # This handles: "users" -> User, "bosses" -> Boss
      model_name.underscore.singularize.camelize.constantize
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
