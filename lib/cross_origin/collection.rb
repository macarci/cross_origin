module CrossOrigin
  class Collection < Mongo::Collection
    include CrossOrigin::Options

    attr_reader :default_collection, :model

    def initialize(default_collection, model)
      default_collection.instance_values.each { |name, value| instance_variable_set(:"@#{name}", value) }
      @default_collection = default_collection
      @model = model
    end

    def find(filter = nil, options = {})
      model.with(persistence_context) do |m|
        View.new(self, filter || {}, options, m)
      end
    end

    def distinct(field_name, filter = nil, options = {})
      model.with(persistence_context) do |m|
        View.new(self, filter || {}, options, m).distinct(field_name, options).flatten.uniq
      end
    end

    class View < Mongo::Collection::View

      attr_reader :model

      def cross_view_map
        views = {}
        skip, limit = self.skip, self.limit
        limit = nil if limit && limit < 0
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
        nil
      end

      # from Readable

      def count(options = {})
        cross_views.inject(0) { |count, view| count + view.count(options) }
      end

      def distinct(field_name, options = {})
        invoke_cross(:distinct, field_name, options).reduce([], &:+).uniq
      end

      # from Retryable (none)

      # from Explainable (none)

      # from Writable

      def find_one_and_delete(opts = {})
        invoke_one_cross(:find_one_and_delete, opts)
      end

      def find_one_and_replace(replacement, opts = {})
        invoke_one_cross(:find_one_and_replace, replacement, opts)
      end

      def find_one_and_update(document, opts = {})
        invoke_one_cross(:find_one_and_update, document, opts)
      end

      def delete_many
        Operation::Delete::Result.new(*invoke_cross(:delete_many))
      end

      def delete_one(opts = {})
        result = nil
        cross_views.each do |view|
          result = view.delete_one(opts)
          break if result.deleted_count > 0
        end
        result
      end

      def replace_one(replacement, opts = {})
        result = nil
        cross_views.each do |view|
          result = view.replace_one(replacement, opts)
          break if result.modified_count > 0
        end
        result
      end

      def update_many(spec, opts = {})
        Operation::Update::Result.new(*invoke_cross(:update_many, spec, opts))
      end

      def update_one(spec, opts = {})
        result = nil
        cross_views.each do |view|
          result = view.update_one(spec, opts)
          break if result.modified_count > 0
        end
        result
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

      def invoke_one_cross(method, *args, &block)
        doc = nil
        cross_views.each do |view|
          unless view.limit == 0
            doc = view.send(method, *args, &block)
          end
          break if doc
        end
        doc
      end
    end
  end
end