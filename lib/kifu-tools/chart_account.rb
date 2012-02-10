
module Kifu
  module Tools
    
    class ChartAccount < KifuModel
            
      def initialize(params = {})
        @model = {
          code: '',
          name: '',
          kind: ''
        }
        @model.merge!(params)
      end
      
      def errors
        array = []

        array << "Must have a kind" if @model[:kind] == ''
        array << "Must have a code" if @model[:code] == ''
        array << "Must have a name" if @model[:name] == ''
        
        # Not validating kinds...
        
        array
      end
      
    end
    
  end
end
