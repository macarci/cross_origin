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

      def cross_view_map
        views = {}
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
          views[config.name] = (previous_view = config.collection_for(model).find(selector, opts).modifiers(modifiers))
        end
        views
      end

      def cross_views
        cross_view_map.values
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
          invoke_cross(:each, &block)
        end
      end

      # from Immutable (none)

      # from Iterable

      def close_query
        invoke_unlimited_cross(:close_query)
      end

      # from Readable

      def count(options = {})
        super + (options[:super] ? 0 : cross_views.inject(0) { |count, view| count + view.count })
      end

      def distinct(field_name, options={})
        invoke_cross(:distinct, field_name, options)
      end

      # from Retryable (none)

      # from Explainable (none)

      # from Writable

      def find_one_and_delete
        invoke_cross(:find_one_and_delete)
      end

      def find_one_and_replace(replacement, opts = {})
        invoke_cross(:find_one_and_replace, replacement, opts)
      end

      def find_one_and_update(document, opts = {})
        invoke_cross(:find_one_and_update, document, opts)
      end

      def delete_many
        invoke_cross(:delete_many)
      end

      def delete_one
        invoke_cross(:delete_one)
      end

      def replace_one(replacement, opts = {})
        invoke_cross(:replace_one, replacement, opts)
      end

      def update_many(spec, opts = {})
        invoke_cross(:update_many, spec, opts)
      end

      def update_one(spec, opts = {})
        invoke_cross(:update_one, spec, opts)
      end

      private

      def invoke_unlimited_cross(method, *args, &block)
        response = [method(method).super_method.call(*args, &block)]
        cross_views.each { |view| response << view.send(method, *args, &block) }
        response
      end

      def invoke_cross(method, *args, &block)
        response =
          if limit == 0
            []
          else
            [method(method).super_method.call(*args, &block)]
          end
        cross_views.each { |view| response << view.send(method, *args, &block) unless view.limit == 0 }
        response
      end
    end
  end
end