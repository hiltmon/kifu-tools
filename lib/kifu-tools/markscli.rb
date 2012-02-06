require 'thor'
require 'kifu-tools'

module Kifu
  module Tools

    class MarksCLI < Thor
      
      desc "version", "Displays the current version of the gem"
      def version
        puts "Kifu Tools v#{VERSION}"
      end
      
    end
  
  end
end