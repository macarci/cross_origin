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
        count = 0
        model.origins.each do |origin|
          if (config = CrossOrigin[origin])
            current_collection = config.collection_for(model)
          elsif origin == :default
            current_collection = collection.default_collection
          else
            next
          end
          current_count = current_collection.find(selector).count
          next_skip = next_limit = nil
          if skip || limit
            opts = opts.dup
            if skip
              if current_count < skip
                next_skip = skip - current_count
                skip = current_count
                current_count = 0
              else
                next_skip = 0
                current_count -= skip
              end
              opts[:skip] = skip
            end
            if limit
              next_limit =
                if current_count > limit
                  current_count = limit
                  0
                else
                  limit - current_count
                end
              opts[:limit] = limit
            end
          end
          count += current_count
          views[origin] = current_collection.find(selector, opts).modifiers(modifiers)
          skip = next_skip
          limit = next_limit
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
        cross_views.inject(0) { |count, view| count + view.count }
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
        response = []
        cross_views.each { |view| response << view.send(method, *args, &block) }
        response
      end

      def invoke_cross(method, *args, &block)
        response = []
        cross_views.each do |view|
          unless view.limit == 0
            response << view.send(method, *args, &block)
          end
        end
        response
      end
    end
  end
end