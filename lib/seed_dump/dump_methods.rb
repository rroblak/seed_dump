require "true"
require "clip"

class SeedDump
  module DumpMethods

    def initialize
      @opts = {}
      @ar_options = {}
      @indent = ""
      @models = []
      @seed_rb = ""
      @id_set_string = ""
    end

    def setup(env)
      # config
      @opts['verbose'] = env["VERBOSE"].true? || env['VERBOSE'].nil?
      @opts['debug'] = env["DEBUG"].true?
      @opts['exclude'] = env['EXCLUDE'].nil? ? ['id', 'created_at', 'updated_at'] : env['EXCLUDE'].split(',').map {|x| x.strip}
      @opts['models']  = env['MODELS'] || env['MODEL'] || ""
      @opts['file']    = env['FILE'] || "#{Rails.root}/db/seeds.rb"
      @opts['append']  = (env['APPEND'].true? && File.exists?(@opts['file']) )
      @opts['max']     = env['MAX'] && env['MAX'].to_i > 0 ? env['MAX'].to_i : nil
      @indent          = " " * (env['INDENT'].nil? ? 2 : env['INDENT'].to_i)
      @opts['create_method']  = env['CREATE_METHOD'] || 'create!'

      @limit = (env['LIMIT'].to_i > 0) ? env['LIMIT'].to_i : nil

      @models = @opts['models'].split(',').collect {|x| x.strip.underscore.singularize.camelize.constantize }
    end

    def log(msg)
      puts msg if @opts['debug']
    end

    def models
      @models
    end

    def dump_attribute(a_s, r, k, v)
      if v.is_a?(BigDecimal)
        v = v.to_s
      else
        v = attribute_for_inspect(r,k)
      end

      if @opts['exclude'].include?(k)
        false
      else
        a_s.push("#{k.to_sym.inspect} => #{v}")

        true
      end
    end

    def dump_model(model)
      @id_set_string = ''
      create_hash = ""
      rows = []


      model.find_each(batch_size: (@limit || 1000)) do |record|
        attr_s = [];

        record.attributes.select {|x| x.is_a?(String) }.each do |k,v|
          dump_attribute(attr_s, record, k, v)
        end

        rows.push "#{@indent}{ " << attr_s.join(', ') << " }"

        break if rows.length == @limit
      end

      if @opts['max']
        splited_rows = rows.each_slice(@opts['max']).to_a
        maxsarr = []
        splited_rows.each do |sr|
          maxsarr << "\n#{model}.#{@opts['create_method']}([\n" << sr.join(",\n") << "\n])\n"
        end
        maxsarr.join('')
      else
        "\n#{model}.#{@opts['create_method']}([\n" << rows.join(",\n") << "\n])\n"
      end

    end

    def dump_models
      if @models.empty?
        Rails.application.eager_load!

        @seed_rb = ""

        @models = ActiveRecord::Base.descendants.select do |model|
                    (model.to_s != 'ActiveRecord::SchemaMigration') && \
                     model.table_exists? && \
                     model.exists?
        end
      end

      @models.sort! { |a, b| a.to_s <=> b.to_s }

      @models.each do |model|
        puts "Adding #{model} seeds." if @opts['verbose']

        @seed_rb << dump_model(model) << "\n\n"
      end

      @seed_rb
    end

    def write_file
      File.open(@opts['file'], (@opts['append'] ? "a" : "w")) { |f|
        f << "# encoding: utf-8\n"
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

    def output
      @seed_rb
    end

    def run(env)
      setup env

      puts "Appending seeds to #{@opts['file']}." if @opts['append']
      dump_models

      puts "Writing #{@opts['file']}."
      write_file

      puts "Done."
    end
  end
end
