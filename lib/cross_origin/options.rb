module CrossOrigin
  module Options

    def persistence_options
      @persistence_options || {}
    end

    def with(options)
      @persistence_options = options
    end
  end
end

require 'mongoid/clients/options'

module Mongoid
  module Clients

    #Patch
    def class_with_options
      self.class
    end

    def collection_name
      super || class_with_options.collection_name
    end

    module Options
      class Proxy

        def method_missing(name, *args, &block)
          set_persistence_options(@target, @options)
          ret = @target.send(name, *args, &block)
          #Patch to capture persistence options with cross_origin
          if ret.class <= Mongoid::Criteria || ret.is_a?(CrossOrigin::Options)
            ret.with @options
          end
          #Patch to keep persistence options when invoking mongoid_root_class
          if name.to_sym == :mongoid_root_class && !@options.empty?
            if ret == @target
              ret = self
            else
              opts = @options.reject { |k, _| k.to_sym == :collection }
              ret = ret.with(opts) unless opts.empty?
            end
          end
          ret
        ensure
          set_persistence_options(@target, nil)
        end
      end
    end
  end
end