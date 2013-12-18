# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "activerecord-runivedo"
  spec.version       = "0.0.1"
  spec.authors       = ["Lucas Clemente"]
  spec.email         = ["luke.clemente@gmail.com"]
  spec.description   = %q{ActiveRecord adapter for Univedo}
  spec.summary       = %q{ActiveRecord adapter for Univedo, see https://github.com/univedo/activerecord-runivedo for more information.}
  spec.homepage      = "https://github.com/univedo/activerecord-runivedo"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "runivedo"
  spec.add_dependency "activerecord", "~>4.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rake"
end
