
module Kifu
  module Tools
    
    class Tag < KifuModel
            
      def initialize(params = {})
        @model = {
          legacy_id: '',
          tag: '',
          implies: false
        }
        @model.merge!(params)
      end
      
      def errors
        []
      end
      
    end
    
  end
end
