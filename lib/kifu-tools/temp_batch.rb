
module Kifu
  module Tools
    
    class TempBatch < KifuModel
            
      def initialize(params = {})
        @model = {
          legacy_id: '',
          batch_date: '',
          batch_count: 0
        }
        @model.merge!(params)
      end
      
      def errors
        array = []
        
        array << "Must have a batch_date" if @model[:batch_date] == ''
        array << "Must have a count > 0" if @model[:batch_count] == 0
        
        array
      end
      
    end
    
  end
end
