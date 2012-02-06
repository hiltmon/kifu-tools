$LOAD_PATH << './lib'
require 'kifu-tools'

class Test < Thor
  desc "version", "version task"
  def version
    puts "Kifu Tools v#{Kifu::Tools::VERSION}"
  end
end