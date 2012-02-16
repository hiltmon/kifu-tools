
module Kifu
  module Tools
    
    class Address < KifuModel
            
      def initialize(params = {})
        @model = {
          person_id: '',
          kind: '',
          street: '',
          extended: '',
          city: '',
          state: '',
          post_code: '',
          country: '',
          pref: false,
        }
        @model.merge!(params)
      end
      
      def errors
        array = []

        array << "Must have a street" if @model[:street] == ''
        array << "Must have a city" if @model[:city] == ''
        array << "Must have a state" if @model[:state] == ''
        array << "Must have a post_code" if @model[:post_code] == ''
        
        array << "Must be home or work" if @model[:kind] != 'home' && @model[:kind] != 'work'
        
        array << "Zip must be numbers" if @model[:postcode] =~ /[^\d-]/ # Not digits and -
        
        array
      end
      
    end
    
  end
end
