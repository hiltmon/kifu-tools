
module Kifu
  module Tools
    
    class Relationship < KifuModel
            
      def initialize(params = {})
        @model = {
          person_legacy_id: '',
          relative_legacy_id: '',
          relationship: ''
        }
        @model.merge!(params)
      end
      
      def errors
        array = []
        array << "Must have a relationship" if @model[:relationship] == ''
        
        array
      end
      
    end
    
  end
end
