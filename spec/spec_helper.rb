require 'bundler/setup'
require 'simplecov'
require 'tmpdir'

if ENV['TRAVIS']
	require 'coveralls'
	SimpleCov.formatter = Coveralls::SimpleCov::Formatter
end

# Start code coverage for all testing
SimpleCov.start

RSpec.configure do |config|

	config.expect_with :rspec do |c|
		c.syntax = :expect
	end

end

shared_context 'rake' do

	let(:tempdir) { File.join Dir.tmpdir, "test_rake_#{$$}" }
	let(:rake)    { Rake::Application.new }

	before do
		ARGV.clear

		@verbose = ENV['VERBOSE']

		@orig_pwd          = Dir.pwd
		@orig_appdata      = ENV['APPDATA']
		@orig_home         = ENV['HOME']
		@orig_homedrive    = ENV['HOMEDRIVE']
		@orig_homepath     = ENV['HOMEPATH']
		@orig_rake_columns = ENV['RAKE_COLUMNS']; ENV.delete 'RAKE_COLUMNS'
		@orig_rake_system  = ENV['RAKE_SYSTEM'];  ENV.delete 'RAKE_SYSTEM'
		@orig_rakeopt      = ENV['RAKEOPT'];      ENV.delete 'RAKEOPT'
		@orig_userprofile  = ENV['USERPROFILE']

		# Create and change to the temp dir.
		FileUtils.mkdir_p tempdir
		Dir.chdir         tempdir

		Rake.application                       = rake
		Rake::TaskManager.record_task_metadata = true
		RakeFileUtils.verbose_flag             = false

	end

	after do

		Dir.chdir @orig_pwd
		FileUtils.rm_rf tempdir

		if @orig_appdata
			ENV['APPDATA'] = @orig_appdata
		else
			ENV.delete 'APPDATA'
		end

		ENV['HOME']         = @orig_home
		ENV['HOMEDRIVE']    = @orig_homedrive
		ENV['HOMEPATH']     = @orig_homepath
		ENV['RAKE_COLUMNS'] = @orig_rake_columns
		ENV['RAKE_SYSTEM']  = @orig_rake_system
		ENV['RAKEOPT']      = @orig_rakeopt
		ENV['USERPROFILE']  = @orig_userprofile

	end

end
