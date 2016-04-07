
module CrossOrigin
  module Document
    extend ActiveSupport::Concern

    included do
      field :origin, type: Symbol, default: :default

      attr_readonly :origin

      validates_inclusion_of :origin, in: ->(doc) { doc.origin_enum }

      def origin_enum
        [:default] + CrossOrigin.names.to_a
      end

      def collection_name
        origin == :default ? super : CrossOrigin[origin].collection_name_for(self.class)
      end

      def client_name
        origin == :default ? super : CrossOrigin[origin].name
      end
    end

    module ClassMethods

      def collection
        CrossOrigin::Collection.new(super, self)
      end

      def mongoid_root_class
        @mongoid_root_class ||=
          begin
            root = self
            root = root.superclass while root.superclass.include?(Mongoid::Document)
            root
          end
      end
    end
  end
end