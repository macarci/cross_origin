require 'cross_origin/version'
require 'cross_origin/options'
require 'cross_origin/operation/cross_result'
require 'cross_origin/operation/result'
require 'cross_origin/operation/delete/result'
require 'cross_origin/operation/update/result'
require 'cross_origin/collection'
require 'cross_origin/document'
require 'cross_origin/criteria'

module CrossOrigin

  class << self

    def to_name(origin)
      if origin.is_a?(Symbol)
        origin
      else
        origin.to_s.to_sym
      end
    end

    def [](origin)
      origin_options[to_name(origin)]
    end

    def config(origin, options = {}, &block)
      origin = to_name(origin)
      fail "Not allowed for origin name: #{origin}" if origin == :default
      origin_options[origin] || (origin_options[origin] = Config.new(origin, options))
    end

    def configurations
      origin_options.values
    end

    def configurations_for(model)
      model.origins.collect { |origin| origin_options[origin] }.compact
    end

    def names
      [:default] + origin_options.keys.to_a
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
      @options = options || {}
    end

    def collection_name_for(model)
      case (collection = options[:collection])
      when NilClass
        "#{name}_#{model.mongoid_root_class.storage_options_defaults[:collection]}"
      when Proc
        collection.call(model)
      else
        collection.to_s.collectionize
      end.to_s.to_sym
    end

    def collection_for(model)
      (Mongoid::Clients.clients[name] || Mongoid.default_client)[collection_name_for(model)]
    end
  end
end