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
        origins[record.collection] << record.id
        doc = record.send(:_reload)
        doc['origin'] = origin
        docs << doc
      end
      klass.with(persistence_context) do |klass_with_persistence_context|
        (cross_origin&.collection_for(klass_with_persistence_context) || klass_with_persistence_context.collection).insert_many(docs) unless docs.empty?
      end
      origins.each { |collection, ids| collection.find(_id: { '$in' => ids }).delete_many }
    end
  end
end