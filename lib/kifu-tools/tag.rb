
module Kifu
  module Tools
    
    class Tag < KifuModel
            
      def initialize(params = {})
        @model = {
          name: '',
          category: '',
          legacy_id: '',
          membership: false,
          solicitor: false,
          hidden: false
        }
        @model.merge!(params)
      end
      
      def errors
        []
      end
      
    end
    
  end
end
