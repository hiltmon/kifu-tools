$LOAD_PATH << './lib'
require 'kifu-tools'

class Import < Thor
  
  desc "marks CONFIG_FILE MARKS_FOLDER DEST_FOLDER", "Creates the import data from a set of MARKS files"
  def marks(config, folder, dest)
    import = Kifu::Tools::MarksImport.new(config, folder, dest)
    import.perform
  end
  
  desc "version", "Displays the current version of the gem"
  def version
    puts "Kifu Tools v#{Kifu::Tools::VERSION}"
  end
  
end