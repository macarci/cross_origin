require 'cross_origin/version'
require 'cross_origin/collection'
require 'cross_origin/document'

module CrossOrigin

  class << self

    def [](origin)
      origin = origin.to_s.to_sym unless origin.is_a?(Symbol)
      origin_options[origin]
    end

    def config(origin, options = {})
      origin = origin.to_s.to_sym unless origin.is_a?(Symbol)
      fail "Not allowed for origin name: #{origin}" if origin == :default
      origin_options[origin] || (origin_options[origin] = Config.new(origin, options))
    end

    def configurations
      origin_options.values
    end

    def names
      origin_options.keys
    end

    private

    def origin_options
      @origin_options ||= {}
    end
  end

  private

  class Config

    attr_reader :name, :options

    def initialize(name, options)
      @name = name
      @options = options
    end

    def collection_name_for(model)
      "#{name}_#{model.mongoid_root_class.storage_options_defaults[:collection]}"
    end

    def collection_for(model)
      (Mongoid::Clients.clients[name] || Mongoid.default_client)[collection_name_for(model)]
    end
  end
end