$:.push File.expand_path("../lib", __FILE__)

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "without_test_helper"
  s.version     = "0.0.1"
  s.authors     = ["Without Software (James Roscoe)"]
  s.email       = ["james@withoutsoftware.com"]
  s.homepage    = "http://withoutsoftware.com"
  s.summary     = "Multi-role controller tests and other helpful assertions"
  s.description = "Best if used with may_may gem. Takes the pain out of testing controllers against multiple use roles."

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["test/**/*"]
end
