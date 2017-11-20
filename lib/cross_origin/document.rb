module CrossOrigin
  module Document
    extend ActiveSupport::Concern

    included do
      field :origin, type: Symbol, default: -> { class_with_options.default_origin }

      attr_readonly :origin

      validates_inclusion_of :origin, in: ->(doc) { doc.origin_enum }
    end

    def class_with_options
      if persistence_options
        self.class.with(persistence_options)
      else
        self.class
      end
    end

    def origin_enum
      [:default] + class_with_options.origins
    end

    def collection_name
      origin == :default ? super : CrossOrigin[origin].collection_name_for(class_with_options)
    end

    def client_name
      origin == :default ? super : CrossOrigin[origin].name
    end

    def can_cross?(origin)
      self.origin != origin && (CrossOrigin[origin] || origin == :default) && origin_enum.include?(origin)
    end

    def cross(origin = :default)
      origin = CrossOrigin.to_name(origin)
      return false unless can_cross?(origin)
      query = collection.find(_id: attributes['_id'])
      doc = query.first
      query.delete_one
      doc['origin'] = origin
      attributes['origin'] = origin
      collection.insert_one(doc)
    end

    module ClassMethods

      def queryable
        CrossOrigin::Criteria.new(super)
      end

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

      def origins_config
        @origins ||
          (superclass.include?(CrossOrigin::Document) ? superclass.origins_config : nil)
      end

      def origins(*args)
        if args.length == 0
          if @origins
            @origins.collect do |origin|
              if origin.respond_to?(:call)
                origin.call
              else
                origin
              end
            end.flatten.uniq.compact.collect do |origin|
              if origin.is_a?(Symbol)
                origin
              else
                origin.to_s.to_sym
              end
            end.uniq
          else
            superclass.include?(CrossOrigin::Document) ? superclass.origins : CrossOrigin.names
          end
        else
          @origins = args.flatten.collect do |arg|
            if arg.respond_to?(:call)
              arg
            else
              arg.to_s.to_sym
            end
          end
        end
      end

      def default_origin(*args, &block)
        if args.length == 0 && block.nil?
          if (@default_origin ||= :default).respond_to?(:call)
            @default_origin.call
          else
            @default_origin
          end
        else
          unless (@default_origin = args[0] || block || :default).respond_to?(:call)
            @default_origin = default_origin.to_s.to_sym
          end
        end
      end
    end
  end
end