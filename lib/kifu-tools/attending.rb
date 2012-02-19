
module Kifu
  module Tools
    
    class Attending < KifuModel
            
      def initialize(params = {})
        @model = {
          person_id: '',
          event_id: '',
          rsvp_status: '',
          acceptance_status: '',
          no_of: 1,
          registration_billing_id: '',
          attendance_billing_id: '',
          donation_billing_id: ''
        }
        @model.merge!(params)
      end
      
      def errors
        array = []

        array << "Must have a person" if @model[:person_id] == ''        
        array << "Must have an event" if @model[:event_id] == ''        
        
        array
      end
      
    end
    
  end
end
