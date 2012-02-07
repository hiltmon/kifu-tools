
module Kifu
  module Tools
    
    class PersonMilestone < KifuModel
            
      def initialize(params = {})
        @model = {
          person_legacy_id: '',
          milestone: '',
          on: '',
          after_sunset: false
        }
        @model.merge!(params)
      end
      
      def errors
        array = []
        array << "Must have a milestone" if @model[:milestone] == ''
        array << "Must have a date" if @model[:on] == ''
        
        array
      end
      
    end
    
  end
end
