
module Kifu
  module Tools
    
    class Occupation < KifuModel
            
      def initialize(params = {})
        @model = {
          name: ''
        }
        @model.merge!(params)
      end
      
      def errors
        array = []

        array << "Must have a name" if @model[:name] == ''
        
        array
      end
      
    end
    
  end
end
