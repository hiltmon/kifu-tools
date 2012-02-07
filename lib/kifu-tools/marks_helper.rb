module Kifu
  module Tools

    class MarksHelper
      
      # In MARKS, gender is in the code, else if none set, use the prefix
      def self.gender(prefix, code)
        return 'F' if code == 'F'
        return 'M' if code == 'M'
        
        # No code, try prefix
        Helper::gender_from_prefix(prefix.downcase)
      end
      
    end
  
  end
  
end
