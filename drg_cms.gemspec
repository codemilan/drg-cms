$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "drg_cms/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "drg_cms"
  s.version     = DrgCms::VERSION
  s.authors     = ["Damjan Rems"]
  s.email       = ["damjan.rems@gmail.com"]
  s.homepage    = "http://www.drgcms.org"
  s.summary     = "DRG CMS: CMS for Ruby, Rails and MongoDB"
  s.description = "DRG CMS: Content management system for Ruby, Rails and MongoDB"
  s.license     = "MIT-LICENSE"

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.md", "drg_cms.gemspec"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency 'rails' #, '~> 3.2.16'
  s.add_dependency 'jquery-rails'
  s.add_dependency 'jquery-ui-rails'

  s.add_dependency 'bcrypt' #, '~> 3.0.0'
  s.add_dependency 'bson'
  s.add_dependency 'mongoid'
  s.add_dependency 'kaminari'
  s.add_dependency 'font-awesome-rails'
end
