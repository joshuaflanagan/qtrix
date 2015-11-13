# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'qtrix/version'

Gem::Specification.new do |gem|
  gem.name          = "qtrix"
  gem.version       = Qtrix::VERSION
  gem.authors       = ["Lance Woodson", "Joshua Flanagan"]
  gem.email         = ["jflanagan@peopleadmin.com"]
  gem.description   = %q{Central worker queues config}
  gem.summary       = gem.description
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  gem.add_dependency "redis-namespace", "~> 1.2"
  gem.add_dependency "mixlib-cli", "1.3.0"
  gem.add_development_dependency 'rake', '~> 0.9'
  gem.add_development_dependency "rspec-core", "2.11.0"
  gem.add_development_dependency "rspec-prof", "0.0.5"
end
