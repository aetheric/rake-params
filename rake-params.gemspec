
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) \
		unless $LOAD_PATH.include?(lib)

require 'rake-params/version'

Gem::Specification.new do |spec|
	spec.name    = 'rake-params'
	spec.version = RakeParams::VERSION
	spec.authors = [ 'Peter Cummuskey' ]
	spec.email   = [ 'peterc@aetheric.co.nz' ]

	spec.summary  = %q{A rake task that provides complex parameter functions.}
	spec.homepage = 'https://www.aetheric.co.nz/rake-params'
	spec.license  = 'MIT'

	spec.files         = Dir.glob('lib/**/*') + [ 'README.md' ]
	spec.require_paths = [ 'lib' ]

	spec.required_ruby_version = '>= 2.5'

	spec.add_development_dependency 'bundler',   '~> 1.16'
	spec.add_development_dependency 'coveralls', '~> 0.8'
	spec.add_development_dependency 'rspec',     '~> 3.0'
	spec.add_development_dependency 'simplecov', '~> 0.16'

	spec.add_runtime_dependency 'rake',   '~> 12.3'
	spec.add_runtime_dependency 'sym',    '~> 2.8'
	spec.add_runtime_dependency 'dotenv', '~> 2.5'

end

