module CrossOrigin
  class Criteria < Mongoid::Criteria

    def initialize(criteria)
      criteria.instance_values.each { |name, value| instance_variable_set(:"@#{name}", value) }
    end

    def cross(origin = :default)
      origin = CrossOrigin.to_name(origin)
      cross_origin = CrossOrigin[origin]
      return unless cross_origin || origin == :default
      origins = Hash.new { |h, k| h[k] = [] }
      docs = []
      each do |record|
        next unless record.can_cross?(origin)
        if persistence_context
          record = record.with(persistence_options) unless record.persistence_options
        end
        origins[record.collection] << record.id
        doc = record.send(:_reload)
        doc['origin'] = origin
        docs << doc
      end
      klass_with_options =
        if persistence_context
          klass.with(persistence_context)
        else
          klass
        end
      ((cross_origin && cross_origin.collection_for(klass_with_options)) || klass_with_options.collection).insert_many(docs) unless docs.empty?
      origins.each { |collection, ids| collection.find(_id: { '$in' => ids }).delete_many }
    end
  end
end