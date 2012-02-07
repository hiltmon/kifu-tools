# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "kifu-tools/version"

Gem::Specification.new do |s|
  s.name        = "kifu-tools"
  s.version     = Kifu::Tools::VERSION
  s.authors     = ["Hilton Lipschitz"]
  s.email       = ["hiltmon@noverse.com"]
  s.homepage    = ""
  s.summary     = %q{Import tools for Kifu}
  s.description = %q{Import toold for Kifu http://www.kifuapp.com}

  s.rubyforge_project = "kifu-tools"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "i18n"
  s.add_dependency "json"
  s.add_dependency "thor"
  s.add_dependency "dbf"
  s.add_development_dependency "rspec"
  s.add_development_dependency "guard"
  s.add_development_dependency "guard-rspec"
  s.add_development_dependency "rb-fsevent"
  s.add_development_dependency "growl_notify"
end
