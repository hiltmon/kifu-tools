
module Kifu
  module Tools
    
    class PersonTag < KifuModel
            
      def initialize(params = {})
        @model = {
          person_legacy_id: '',
          tag_legacy_id: ''
        }
        @model.merge!(params)
      end
      
      def errors
        array = []
        
        array << "Must match a tag" if @model[:tag_legacy_id] == '' || @model[:tag_legacy_id] == nil
        
        array
      end
      
    end
    
  end
end
