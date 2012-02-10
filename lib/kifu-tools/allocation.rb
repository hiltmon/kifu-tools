
module Kifu
  module Tools
    
    class Allocation < KifuModel
            
      def initialize(params = {})
        @model = {
          payment_legacy_id: '',
          billing_legacy_id: '',
          allocation_amount: ''
        }
        @model.merge!(params)
      end
      
      def errors
        array = []

        array << "Must have a payment" if @model[:payment_legacy_id] == ''        
        array << "Must have a billing" if @model[:billing_legacy_id] == ''        
        
        array
      end
      
    end
    
  end
end
