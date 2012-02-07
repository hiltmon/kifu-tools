module Kifu
  module Tools

    class KifuModel
  
      def valid?
        errors.length == 0
      end
      
      def [](key)
        @model[key]
      end

      def []=(key, value)
        @model[key] = value
      end
      
      def to_csv
        '"' + @model.values.join('","') + '"'
      end
      
      def header
        @model.keys.join(',')
      end
    
    end
    
  end
end
