
module Kifu
  module Tools
    
    class Email < KifuModel
            
      def initialize(params = {})
        @model = {
          person_id: '',
          kind: '',
          email_address: '',
          pref: false
        }
        @model.merge!(params)
      end
      
      def errors
        array = []

        array << "Must have an email address" if @model[:email_address] == ''        
        # array << "Must be a valid kind" if @model[:kind] != 'home' && @model[:kind] != 'work'
        
        array
      end
      
    end
    
  end
end
