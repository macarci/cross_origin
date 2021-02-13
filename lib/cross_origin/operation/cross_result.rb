module CrossOrigin
  module Operation
    module CrossResult

      attr_reader :results

      def initialize(*results)
        @results = results
      end

      # @return [ Array<Protocol::Message> ] replies The wrapped wire protocol replies.
      def replies
        results.map(&:replies).reduce(&:+)
      end

      # @return [ Server::Description ] Server description of the server that
      #   the operation was performed on that this result is for.
      #
      # @api private
      def connection_description
        results[0].connection_description
      end

      # Is the result acknowledged?
      #
      # @note To get all the origins acknowledged status call origins_acknowledged.
      #
      # @return [ true, false ] If the result is acknowledged.
      def acknowledged?
        results.map(&:acknowledged?).reduce(&:&)
      end

      # @return [ Array<true, false> ] For each result if it is acknowledged.
      def origins_acknowledged
        results.map(&:acknowledged?)
      end

      # Get the cursor id if the response is acknowledged.
      #
      # @note To get all the origins cursors call origins_cursor_ids.
      #
      # @example Get the cursor id.
      #   result.cursor_id
      #
      # @return [ Integer ] The cursor id.
      def cursor_id
        results.reverse_each do |result|
          if result.acknowledged?
            return result.replies.last.cursor_id
          end
        end
        0
      end

      # @return [ Array<Integer> ] If the result is acknowledged.
      def origins_cursor_ids
        results.map(&:cursor_id)
      end

      # Get the documents in the result.
      #
      # @return [ Array<BSON::Document> ] The documents.
      def documents
        results.map(&:documents).reduce(&:+)
      end

      # Get the first reply from the result.
      #
      # @note To get all the origins replies call origins_replies.
      #
      # @return [ Protocol::Message ] The first reply.
      def reply
        results.each do |result|
          if result.acknowledged?
            return result.replies.first
          end
        end
        nil
      end

      # @return [ Array<Protocol::Message> ] The first reply
      def origins_replies
        results.map(&:reply)
      end

      # Get the count of documents returned by the server.
      #
      # @note To get all the origins documents numbers call origins_returned_count.
      #
      # @return [ Integer ] The number of documents returned.
      def returned_count
        results.map(&:returned_count).reduce(&:+)
      end

      # @return [ Array<Integer> ] The number of documents returned.
      def origins_returned_count
        results.map(&:returned_count)
      end

      # If the result was a command then determine if it was considered a
      # success.
      #
      # @note To get all the origins successful status call origins_successful.
      #
      # @return [ true, false ] If the command was successful.
      def successful?
        results.map(&:successful?).reduce(&:&)
      end

      # @return [ Array<true, false> ] For each result if it is successful?.
      def origins_successful
        results.map(&:successful?)
      end


      # Validate the result by checking for any errors.
      #
      # @raise [ Error::OperationFailure ] If an error is in the result.
      #
      # @return [ Result ] The result if verification passed.
      def validate!
        results.each(&:validate!)
        self
      end

      # Get the number of documents written by the server.
      #
      # @return [ Integer ] The number of documents written.
      def written_count
        results.map(&:written_count).reduce(&:+)
      end
    end
  end
end