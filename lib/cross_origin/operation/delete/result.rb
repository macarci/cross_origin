module CrossOrigin
  module Operation
    module Delete

      class Result < ::Mongo::Operation::Delete::Result
        include Operation::CrossResult

        # Get the number of documents deleted.
        #
        # @return [ Integer ] The deleted count.
        def deleted_count
          n
        end

        def bulk_result
          ::Mongo::Operation::Delete::BulkResult.new(replies, connection_description)
        end
      end
    end
  end
end
