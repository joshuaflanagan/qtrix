# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'orchestrator/version'

Gem::Specification.new do |gem|
  gem.name          = "orchestrator"
  gem.version       = Orchestrator::VERSION
  gem.authors       = ["Lance Woodson", "Joshua Flanagan"]
  gem.email         = ["jflanagan@peopleadmin.com"]
  gem.description   = %q{Central worker queues config}
  gem.summary       = gem.description
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
