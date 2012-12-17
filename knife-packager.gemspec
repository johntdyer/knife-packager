# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/chef/knife', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |gem|
  gem.name          = "knife-packager"
  gem.version       = "0.1.1"
  gem.authors       = ["John Dyer"]
  gem.email         = ["johntdyer@gmail.com"]
  gem.description   = %q{Knife pluging to deploy cookbooks to S3}
  gem.summary       = %q{Knife pluging to deploy cookbooks to S3}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency 'rake'
  gem.add_dependency 'bundler'
  gem.add_dependency 'chef'
  gem.add_dependency 'berkshelf'
  gem.add_dependency 's3'
  gem.add_dependency 'fog'

end
