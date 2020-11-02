module CrossOrigin
  module Options

    def persistence_context
      Mongoid::PersistenceContext.get(self) ||
        Mongoid::PersistenceContext.get(self.class) ||
        Mongoid::PersistenceContext.new(self.class)
    end

    def with(options_or_context, &block)
      original_context = Mongoid::PersistenceContext.get(self)
      original_cluster = persistence_context.cluster
      set_persistence_context(options_or_context)
      yield self
    ensure
      clear_persistence_context(original_cluster, original_context)
    end

    private

    def set_persistence_context(options_or_context)
      Mongoid::PersistenceContext.set(self, options_or_context)
    end

    def clear_persistence_context(original_cluster = nil, context = nil)
      Mongoid::PersistenceContext.clear(self, original_cluster, context)
    end
  end
end

require 'mongoid/clients/options'

module Mongoid
  module Clients

    # TODO This methods might not need to be overridden
    def collection_name
      super || self.class.collection_name
    end
  end
end