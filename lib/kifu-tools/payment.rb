
module Kifu
  module Tools
    
    class Payment < KifuModel
            
      def initialize(params = {})
        @model = {
          legacy_id: '',
          deposit_id: '',
          person_id: '',
          kind: '',
          reference_code: '',
          payment_amount: '',
          allocated_amount: 0.0,
          note: '',
          third_party_id: '',
          honor: '',
          honoree: '',
          notify_id: '',
          decline_date: '',
          decline_posted: false,
          refund_amount: 0
        }
        @model.merge!(params)
      end
      
      def errors
        array = []

        array << "Must have a legacy id" if @model[:legacy_id] == ''
        array << "Must have a deposit id" if @model[:deposit_id] == ''
        array << "Must have a person id" if @model[:person_id] == ''
        array << "Must have a kind" if @model[:kind] == ''
        array << "Must have a payment amount" if @model[:payment_amount] == ''
        
        array
      end
      
    end
    
  end
end
