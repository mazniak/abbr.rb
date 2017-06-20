require 'ostruct'

module Abbr
  module Util
    module_function
    def map_detect(enum, &block)
      enum.each do |item|
        obj = block[item]
        return obj if obj
      end
      nil
    end

    def extract_options!(arr)
      arr.last.is_a?(::Hash) ? arr.pop : {}
    end
  end # Util

  module InstanceMethods
    private
    def initialize(*args)
      super
      @_abbr_memos = {}
      @_abbr_args = Hash[args.each_with_index.to_a.map(&:reverse)]
    end
  end # InstanceMethods

  module ModuleHooks
    private
    def included(mod)
      super
      ModuleHooks.mixin(mod)
    end

    def self.mixin(mod)
      mod.module_eval do
        extend ModuleHooks unless Class === mod
        extend ModuleMethods
        include InstanceMethods unless InstanceMethods > mod
      end
    end
  end # ModuleHooks

  module ModuleMethods
    def let(name, *opts, &block)
      define_abbr_method(name, *opts) {
        @_abbr_memos.fetch(name) do
          @_abbr_memos[name] = instance_eval(&block)
        end
      }
    end

    def static(&block)
      instance_eval(&block)
    end
    
    protected
    def abbr_method?(name)
      config = Util.map_detect(abbr_ancestors) { |m| m.abbr_methods[name] }

      yield(config) if config && block_given?
        
      return !!config
    end

    def abbr_methods
      @abbr_methods || {}
    end

    private
    def abbr_init(*args_aliases, &block)
      abbr_arguments(*args_aliases)
      define_abbr_method(:initialize, :private) do |*args|
        super(*args)
        instance_eval(&block) if block
      end
    end

    def abbr_inspect(&to_s)
      define_method(:inspect) do
        "#<#{self.class.name}: #{instance_eval(&to_s)}>"
      end
    end

    def abbr_arguments(*args_aliases)
      opts = Util.extract_options!(args_aliases)

      undef_abbr_argument_getters

      arg_aliases = (args_aliases.flatten + opts.keys).map(&:to_sym)

      @abbr_arguments_aliases = {}
      arg_aliases.each_with_index do |arg_alias, idx|
        if opts.any? && opts.has_key?(arg_alias)
          let(arg_alias) do
            @_abbr_args.fetch(idx) do
              obj = opts.fetch(arg_alias)
              obj.respond_to?(:duplicable?) ?
                (obj.duplicable? ? obj.dup : obj) : obj
            end
          end
        else
          let(arg_alias) { @_abbr_args.fetch(idx) }
        end

        @abbr_arguments_aliases[arg_alias] = instance_method(arg_alias)
      end

      @abbr_arguments_aliases.freeze

      inspect_args = @abbr_arguments_aliases.keys
      abbr_inspect do
        Hash[inspect_args.map {|i| [ i, __send__(i) ] }]
      end
    end

    def undef_abbr_argument_getters
      imethods = instance_methods
      abbr_arguments_aliases.each do |arg_alias, unbound_meth|
        meth = instance_method(arg_alias) if imethods.include?(arg_alias)
        undef_method(arg_alias) if meth.owner == unbound_meth.owner &&
          meth.source_location == unbound_meth.source_location
      end
    end

    protected
    def abbr_arguments_aliases
      Util.map_detect(abbr_ancestors) { |mod| mod.abbr_arguments_aliases? } || {}
    end

    def abbr_arguments_aliases?
      @abbr_arguments_aliases
    end

    private
    def define_abbr_method(name, *options, &block)
      abbr_method?(name) do |cfg|
        message = "cannot redefine frozen abbr_method `#{name}` " +
                  "(frozen by #{cfg.base})"

        raise message unless !cfg.frozen?
      end

      name = name.to_sym
      cfg = MethodConfig.from_options(self, options)

      @abbr_methods = abbr_methods.merge(name => cfg)

      (block ? define_method(name, &block) : attr_reader(name)).tap do
        private name if cfg.private? || @abbr_privately
      end
    end

    def abbr_ancestors
      ancestors.select { |m| Abbr::ModuleMethods === m }
    end

    def privately(&block)
      abbr_privately_was = @abbr_privately
      @abbr_privately = true
      module_eval(&block)
    ensure
      @abbr_privately = abbr_privately_was
    end
  end # ModuleMethods

  class MethodConfig < OpenStruct
    def base
      x = super
      raise 'bad base config' unless Module === x
      x
    end

    def frozen
      !!super
    end

    def private
      !!super
    end

    alias_method :private?, :private
    alias_method :frozen?, :frozen

    def self.from_options(base, options)
      new(Hash[options.zip([true].cycle) << [ :base, base ]])
    end
  end # MethodConfig

  module Mixin
    def self.extended(mod)
      super
      ModuleHooks.mixin(mod)
    end

    def self.included(mod)
      assert false, "cannot include #{self}; must extend"
    end
  end # Mixin

  class Object
    extend Mixin
  end # Object
end # Abbr