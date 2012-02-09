
module Kifu
  module Tools
    
    class Event < KifuModel
            
      def initialize(params = {})
        @model = {
          legacy_id: '',
          name: '',
          detail: '',
          url: '',
          status: '',
          mandatory: false,
          rsvp: false,
          acceptance: false,
          organizer_id: '',
          booking_person_id: '',
          booking_fee: '',
          booking_billing_id: '',
          start_at: '',
          end_at: '',
          payments_due: '',
          regular_registration_fee: '',
          member_registration_fee: '',
          registration_fee_kind: 'Deposit',
          regular_attendance_fee: '',
          member_attendance_fee: '',
          goal_amount: '',
          tiered: '',
          bank_account_id: '',
          income_account_id: '',
          pro_rata: false,
          old_event_id: '',
          deductible: 0,
          kind: 'Fee'
        }
        @model.merge!(params)
      end
      
      def errors
        array = []

        array << "Must have a legacy id" if @model[:legacy_id] == ''
        array << "Must have a name" if @model[:name] == ''
        
        array
      end
      
    end
    
  end
end
