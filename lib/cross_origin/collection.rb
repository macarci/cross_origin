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

      def initialize(collection, selector, options, model)
        super(collection, selector, options)
        @model = model
      end

      def each(&block)
        if block
          super(&block)
          cross_views.each { |view| view.each(&block) }
        end
      end

      def count(options = {})
        super + (options[:super] ? 0 : cross_views.inject(0) { |count, view| count + view.count })
      end

      def cross_views
        views = []
        skip, limit = self.skip, self.limit
        opts = options
        previous_view = self
        count = 0
        CrossOrigin.configurations.each do |config|
          if skip || limit
            opts = opts.dup
            count += previous_view.count(super: true, skip: 0)
            if skip
              opts[:skip] = skip = (count < skip ? skip - count : 0)
            end
            if limit
              current_skip = skip || 0
              skipped_count = (current_skip > count ? 0 : count - current_skip)
              opts[:limit] = limit = (limit > skipped_count ? limit - skipped_count : 0)
            end
          end
          views << (previous_view = config.collection_for(model).find(selector, opts).modifiers(modifiers))
        end
        views
      end

      def new(options)
        View.new(collection, selector, options, model)
      end
    end
  end
end