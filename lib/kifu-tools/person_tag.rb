
module Kifu
  module Tools
    
    class PersonTag < KifuModel
            
      def initialize(params = {})
        @model = {
          person_id: '',
          tag_id: ''
        }
        @model.merge!(params)
      end
      
      def errors
        array = []
        
        array << "Must match a tag" if @model[:tag_id] == '' || @model[:tag_id] == nil
        
        array
      end
      
    end
    
  end
end
