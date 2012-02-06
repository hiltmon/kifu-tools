$LOAD_PATH << './lib'
require 'kifu-tools'

class Import < Thor
  desc "version", "Displays the current version of the gem"
  def version
    puts "Kifu Tools v#{Kifu::Tools::VERSION}"
  end
end