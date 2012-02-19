
module Kifu
  module Tools
    
    class TempMemorial < KifuModel
            
      def initialize(params = {})
        @model = {
          person_id: '', # Relative's ID
          gender: '',
          first_name: '',
          last_name: '',
          death_date: '',
          relationship: '',
          new_person_id: '', # New person ID
        }
        @model.merge!(params)
      end
      
      def errors
        array = []

        array << "Must have a gender" if @model[:gender] == ''
        array << "Must have a first name" if @model[:first_name] == ''
        array << "Must have a last name" if @model[:last_name] == ''
        array << "Must have a death date" if @model[:death_date] == ''
        array << "Must have a direct relationship" if @model[:relationship] == ''
        
        array
      end
      
    end
    
  end
end
