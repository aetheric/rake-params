require 'rake'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new :rspec do |task|
	task.pattern = [ 'spec/rake-params/**/*_spec.rb' ]
	task.rspec_opts = [
		'--require spec_helper',
		'--format documentation',
		'--failure-exit-code 2',
		'--color',
	]
end

Bundler::GemHelper.install_tasks
