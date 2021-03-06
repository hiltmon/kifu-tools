
module Kifu
  module Tools
    
    class PersonMilestone < KifuModel
      
      # 1|Birth
      # 2|Death
      # 3|Christening
      # 4|Burial
      # 5|Marriage
      # 6|Divorce
      # 7|Bar/Batmitzvah
      # 8|Confirmation
      
      def initialize(params = {})
        @model = {
          person_id: '',
          milestone_id: '',
          on: '',
          after_sunset: false
        }
        @model.merge!(params)
      end
      
      def errors
        array = []
        array << "Must have a milestone id" if @model[:milestone_id] == ''
        array << "Must have a date" if @model[:on] == ''
        
        array
      end
      
    end
    
  end
end
