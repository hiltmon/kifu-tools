
module Kifu
  module Tools
    
    class Billing < KifuModel
            
      def initialize(params = {})
        @model = {
          person_legacy_id: '',
          event_legacy_id: '',
          bill_date: '',
          bill_for: 'Attendance',
          bill_amount: '',
          payable_amount: '',
          allocated_amount: 0,
          posted_amount: 0,
          status: 'Open',
          posted: false,
          period: '',
          note: '',
          pro_rata_from: '',
          periodic: false,
        }
        @model.merge!(params)
      end
      
      def errors
        array = []

        array << "Must have a person" if @model[:person_legacy_id] == ''        
        array << "Must have an event" if @model[:event_legacy_id] == ''        
        array << "Must have an bill date" if @model[:bill_date] == ''        
        array << "Must have an bill amount" if @model[:bill_amount] == ''
        
        array
      end
      
    end
    
  end
end
