module CrossOrigin
  module Operation
    module Update

      class Result < ::Mongo::Operation::Update::Result
        include Operation::CrossResult

        # Get the number of documents matched.
        #
        # @return [ Integer ] The matched count.
        def matched_count
          results.map(&:matched_count).reduce(&:+)
        end

        # Get the number of documents modified.
        #
        # @return [ Integer ] The modified count.
        def modified_count
          results.map(&:modified_count).reduce(&:+)
        end

        # The identifier of the inserted document if an upsert
        # took place.
        #
        # @return [ Object ] The upserted id.
        def upserted_id
          result.each do |result|
            next unless upsert?
            return upsert?.first['_id']
          end
          nil
        end

        # Returns the number of documents upserted.
        #
        # @return [ Integer ] The number upserted.
        def upserted_count
          results.map(&:upserted_count).reduce(&:+)
        end

        def bulk_result
          ::Mongo::Operation::Update::BulkResult.new(replies, connection_description)
        end

        def upsert?
          results.any?(&:upsert?)
        end
      end
    end
  end
end
