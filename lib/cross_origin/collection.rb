module CrossOrigin
  class Collection < Mongo::Collection

    attr_reader :default_collection, :model

    def initialize(default_collection, model)
      default_collection.instance_values.each { |name, value| instance_variable_set(:"@#{name}", value) }
      @default_collection = default_collection
      @model = model
    end

    def find(filter = nil, options = {})
      View.new(self, filter || {}, options, model)
    end

    class View < Mongo::Collection::View

      attr_reader :model

      def cross_views
        views = []
        skip, limit = self.skip, self.limit
        opts = options
        previous_view = self
        count = 0
        CrossOrigin.configurations_for(model).each do |config|
          if skip || limit
            opts = opts.dup
            current_count = previous_view.count(super: true)
            if skip
              opts[:skip] = skip =
                if current_count < skip
                  skip - current_count
                else
                  count += current_count - skip
                  0
                end
            end
            if limit
              opts[:limit] = limit =
                if count > limit
                  0
                else
                  limit - count
                end
            end
          end
          views << (previous_view = config.collection_for(model).find(selector, opts).modifiers(modifiers))
        end
        views
      end

      # from class View

      def initialize(collection, selector, options, model)
        super(collection, selector, options)
        @model = model
      end

      def ==(other)
        return false unless other.is_a?(View)
        collection == other.collection &&
          filter == other.filter &&
          options == other.options
      end

      def new(options)
        View.new(collection, selector, options, model)
      end

      # from Enumerable

      def each(&block)
        if block
          super(&block)
          cross_views.each { |view| view.each(&block) }
        end
      end

      # from Immutable (none)

      # from Iterable

      def close_query
        invoke_cross(:close_query, super)
      end

      # from Readable

      def count(options = {})
        super + (options[:super] ? 0 : cross_views.inject(0) { |count, view| count + view.count })
      end

      def distinct(field_name, options={})
        invoke_cross(:distinct, super, field_name, options)
      end

      # from Retryable (none)

      # from Explainable (none)

      # from Writable

      def find_one_and_delete
        invoke_cross(:find_one_and_delete, super)
      end

      def find_one_and_replace(replacement, opts = {})
        invoke_cross(:find_one_and_replace, super, replacement, opts)
      end

      def find_one_and_update(document, opts = {})
        invoke_cross(:find_one_and_update, super, document, opts)
      end

      def delete_many
        invoke_cross(:delete_many, super)
      end

      def delete_one
        invoke_cross(:delete_one, super)
      end

      def replace_one(replacement, opts = {})
        invoke_cross(:replace_one, super, replacement, opts)
      end

      def update_many(spec, opts = {})
        invoke_cross(:update_many, super, spec, opts)
      end

      def update_one(spec, opts = {})
        invoke_cross(:update_one, super, spec, opts)
      end

      private

      def invoke_cross(method, super_response, *args)
        response = [super_response]
        cross_views.each { |view| response << view.send(method, *args) }
        response
      end
    end
  end
end