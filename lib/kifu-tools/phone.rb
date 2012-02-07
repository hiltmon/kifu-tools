
module Kifu
  module Tools
    
    class Phone < KifuModel
            
      def initialize(params = {})
        @model = {
          person_legacy_id: '',
          kind: '',
          phone_number: '',
          pref: false
        }
        @model.merge!(params)
      end
      
      def errors
        array = []

        array << "Must have a number" if @model[:phone_number] == ''        
        # array << "Must be a valid kind" if @model[:kind] != 'home' && @model[:kind] != 'work'
        
        array
      end
      
    end
    
  end
end
