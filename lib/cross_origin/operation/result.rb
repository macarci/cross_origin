module CrossOrigin
  module Operation
    class Result < ::Mongo::Operation::Result
      include CrossResult
    end
  end
end