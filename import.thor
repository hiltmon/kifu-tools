$LOAD_PATH << './lib'
require 'kifu-tools'

class Import < Thor
  
  desc "marks CONFIG FOLDER", "Creates the import data from a set of MARKS files"
  def marks(config, folder)
    import = Kifu::Tools::MarksImport.new(config, folder)
    import.perform
  end
  
  desc "version", "Displays the current version of the gem"
  def version
    puts "Kifu Tools v#{Kifu::Tools::VERSION}"
  end
  
end