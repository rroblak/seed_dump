require "true"
require "clip"

module SeedDump
  class Perform

    def initialize
      @opts = {}
      @ar_options = {}
      @indent = ""
      @models = []
      @last_record = []
      @seed_rb = ""
      @id_set_string = ""
      @model_dir = 'app/models/**/*.rb'
    end

    def setup(env)
      # config
      @opts['verbose'] = env["VERBOSE"].true? || env['VERBOSE'].nil?
      @opts['debug'] = env["DEBUG"].true?
      @opts['with_id'] = env["WITH_ID"].true?
      @opts['timestamps'] = env["TIMESTAMPS"].true? || env["TIMESTAMPS"].nil?
      @opts['no-data'] = env['NO_DATA'].true?
      @opts['without_protection'] = env['WITHOUT_PROTECTION'].true? || (env['WITHOUT_PROTECTION'].nil? && @opts['timestamps'])
      @opts['skip_callbacks'] = env['SKIP_CALLBACKS'].true?
      @opts['models']  = env['MODELS'] || (env['MODEL'] ? env['MODEL'] : "")
      @opts['file']    = env['FILE'] || "#{Rails.root}/db/seeds.rb"
      @opts['append']  = (env['APPEND'].true? && File.exists?(@opts['file']) )
      @opts['max']     = env['MAX'] && env['MAX'].to_i > 0 ? env['MAX'].to_i : nil
      @ar_options      = env['LIMIT'].to_i > 0 ? { :limit => env['LIMIT'].to_i } : {}
      @indent          = " " * (env['INDENT'].nil? ? 2 : env['INDENT'].to_i)
      @opts['models']  = @opts['models'].split(',').collect {|x| x.underscore.singularize.camelize }
      @opts['schema']  = env['PG_SCHEMA']
      @opts['model_dir']  = env['MODEL_DIR'] || @model_dir
      @opts['create_method']  = env['CREATE_METHOD'] || 'create'
      @opts['rails4'] = env['RAILS4'].true?
      monkeypatch_AR if @opts['rails4']
    end

    def monkeypatch_AR
      ActiveRecord::Base.instance_eval do
        def attr_accessible(*opts)
          nil
        end
      end
    end

    def load_models
      puts "Searching in #{@opts['model_dir']} for models" if @opts['debug']
      Dir[Dir.pwd + '/' + @opts['model_dir']].sort.each do |f|
        puts "Processing file #{f}" if @opts['debug']
        # parse file name and path leading up to file name and assume the path is a module
        f =~ /models\/(.*).rb/
        # split path by /, camelize the constituents, and then reform as a formal class name
        parts = $1.split("/").map {|x| x.camelize}

        # Initialize nested model namespaces
        parts.clip.inject(Object) do |x, y|
          if x.const_defined?(y)
            x.const_get(y)
          else
            x.const_set(y, Module.new)
          end
        end

        model = parts.join("::")
        require f

        puts "Detected model #{model}" if @opts['debug']
        @models.push model if @opts['models'].include?(model) || @opts['models'].empty?
      end
    end

    def models
      @models
    end

    def last_record
      @last_record
    end

    def dump_attribute(a_s, r, k, v)
      pushed = false
      if v.is_a?(BigDecimal)
        v = v.to_s
      else
        v = attribute_for_inspect(r,k)
      end

      unless k == 'id' && !@opts['with_id']
        if (!(k == 'created_at' || k == 'updated_at') || @opts['timestamps'])
          a_s.push("#{k.to_sym.inspect} => #{v}")
          pushed = true
        end
      end
      pushed
    end

    def dump_model(model)
      @id_set_string = ''
      @last_record = []
      create_hash = ""
      options = ''
      rows = []
      arr = []
      arr = model.find(:all, @ar_options) unless @opts['no-data']
      arr = arr.empty? ? [model.new] : arr

      arr.each_with_index { |r,i|
        attr_s = [];
        r.attributes.each do |k,v|
          if (@opts['rails4'] || (model.attr_accessible[:default].include? k) || @opts['without_protection'] || @opts['with_id'])
            pushed_key = dump_attribute(attr_s,r,k,v)
            @last_record.push k if pushed_key
          end
        end
        rows.push "#{@indent}{ " << attr_s.join(', ') << " }"
      }

      if @opts['without_protection']
        options = ', :without_protection => true '
      end

      if @opts['max']
        splited_rows = rows.each_slice(@opts['max']).to_a
        maxsarr = []
        splited_rows.each do |sr|
          maxsarr << "\n#{model}.#{@opts['create_method']}([\n" << sr.join(",\n") << "\n]#{options})\n"
        end
        maxsarr.join('')
      else
        "\n#{model}.#{@opts['create_method']}([\n" << rows.join(",\n") << "\n]#{options})\n"
      end

    end

    def dump_models
      @seed_rb = ""
      @models.sort.each do |model|
          m = model.constantize
          if m.ancestors.include?(ActiveRecord::Base) && !m.abstract_class
            puts "Adding #{model} seeds." if @opts['verbose']

            if @opts['skip_callbacks']
              @seed_rb << "#{model}.reset_callbacks :save\n"
              @seed_rb << "#{model}.reset_callbacks :create\n"
              puts "Callbacks are disabled." if @opts['verbose']
            end

            @seed_rb << dump_model(m) << "\n\n"
          else
            puts "Skipping non-ActiveRecord model #{model}..." if @opts['verbose']
          end
      end
    end

    def write_file
      File.open(@opts['file'], (@opts['append'] ? "a" : "w")) { |f|
        f << "# encoding: utf-8\n"
        f << "# Autogenerated by the db:seed:dump task\n# Do not hesitate to tweak this to your needs\n" unless @opts['append']
        f << "#{@seed_rb}"
      }
    end

    #override the rails version of this function to NOT truncate strings
    def attribute_for_inspect(r,k)
      value = r.attributes[k]

      if value.is_a?(String) && value.length > 50
        "#{value}".inspect
      elsif value.is_a?(Date) || value.is_a?(Time)
        %("#{value.to_s(:db)}")
      else
        value.inspect
      end
    end

    def set_search_path(path, append_public=true)
        path_parts = [path.to_s, ('public' if append_public)].compact
        ActiveRecord::Base.connection.schema_search_path = path_parts.join(',')
    end

    def run(env)

      setup env

      puts "Protection is disabled." if @opts['verbose'] && @opts['without_protection']

      set_search_path @opts['schema'] if @opts['schema']

      load_models

      puts "Appending seeds to #{@opts['file']}." if @opts['append']
      dump_models

      puts "Writing #{@opts['file']}."
      write_file

      puts "Done."
    end
  end
end
