require 'rspec'
require 'securerandom'

require_relative '../spec_helper'
require 'rake-params/param_task'
require 'rake-params/utils'

describe RakeParams::ParamTask do
	include_context 'rake'

	after :each do

		# Remove all generated files
		FileUtils.rm_f Dir.glob("#{tempdir}/*")

		# Clear ENV from previous runs
		ENV.delete 'EXPECTED_PARAM'
		ENV.delete 'EXPECTED_PARAM_ENC'
		ENV.delete 'SECURE_PARAM'
		ENV.delete 'BASIC_PARAM'
		ENV.delete 'VAULT_SECRET'

	end

	it 'should respond to global hash dir configuration' do

		hash_dir = SecureRandom.hex 5
		ENV['DEBUG'] && puts("hash_dir: #{hash_dir}")

		# Initialise ParamTask configuration.
		RakeParams::ParamTask.configure({
			hash_dir: hash_dir
		})

		# Check if hash dir file task exists
		hash_dir_task = Rake.application.lookup hash_dir
		expect(hash_dir_task).to_not be(nil)

		# Define a basic param task
		task = RakeParams::ParamTask.define_task :expected_param

		# Check if task prerequisite includes hash dir
		expect(task.prerequisites).to include(hash_dir)

	end

	it 'should respond to global vault secret param task configuration' do

		vault_secret = SecureRandom.hex 5
		ENV['DEBUG'] && puts("vault_secret: #{vault_secret}")

		# Initialise ParamTask configuration.
		RakeParams::ParamTask.configure({
			vault_secret_param: vault_secret
		})

		# Check if vault secret param task exists
		vault_secret_task = Rake.application.lookup(vault_secret)
		expect(vault_secret_task).to_not be(nil)

		# Define a basic param task
		task_basic = RakeParams::ParamTask.define_task :basic_param

		# Since the param isn't sensitive, make sure it doesn't have the vault secret as a prerequisite
		expect(task_basic.prerequisites).to_not include(vault_secret)

		# Define a secure param task
		task_secure = RakeParams::ParamTask.define_task :secure_param do |task|
			task.sensitive = true
		end

		# Since the param is sensitive, make sure it has the vault secret as a prerequisite
		expect(task_secure.prerequisites).to include(vault_secret)

	end

	it 'should throw an error if a task is defined without config init' do

		begin
			RakeParams::ParamTask.define_task :expected_param
			fail 'An error should have been thrown'

		rescue Exception => error
			expect(error.message).to match(/^You need to run ParamTask.configure before defining tasks.$/)
		end

	end

	describe 'with basic configuration' do

		before :each do

			# Set up the global configuration
			RakeParams::ParamTask.configure

			@param_value = SecureRandom.hex 10
			ENV['DEBUG'] && puts("param_value: #{@param_value}")

		end

		it 'should throw an error if configured twice' do

			begin
				# Second initialisation
				RakeParams::ParamTask.configure
				fail 'An error should have been thrown'

			rescue Exception => error
				expect(error.message).to match(/^Already configured global ParamTask usage.$/)
			end

		end

		describe 'with a basic param task' do

			before :each do

				# Define the basic param task.
				@task = RakeParams::ParamTask.define_task :expected_param

			end

			it 'should error if the defined param hasn\'t been provided' do

				# Make sure the value hasn't been set in the environment.
				expect(ENV.has_key?('EXPECTED_PARAM')).to eq(false)

				begin
					@task.invoke
					fail 'An error should have been thrown.'

				rescue ArgumentError => error
					expect(error.message).to match(/^The parameter 'expected_param' has not been provided or defaulted.$/)
				end

			end

			it 'should resolve if it\'s been provided in the environment' do

				# Set the environment variable
				ENV[@task.env_key] = @param_value

				# Run the task to generate the hash
				@task.invoke

				# Ensure that the hash file has been created.
				expect(File.exists?('.params/expected_param')).to eq(true)

				# Make sure the param resolves to its value.
				resolved_value = @task.resolve
				expect(resolved_value).to eq(@param_value)

			end

			it 'should invalidate downstream tasks when the variable changes' do

				# This tracks how many times the downstream task has run.
				execution_count = 0
				last_value      = nil

				# Create the downstream task
				downstream_task = Rake::FileTask.define_task 'downstream' => :expected_param do |task|
					execution_count += 1
					last_value       = @task.resolve
					FileUtils.touch task.name
				end

				# Generate and set the first value
				ENV[@task.env_key] = @param_value

				# Trigger task execution
				downstream_task.invoke
				expect(execution_count).to eq(1)
				expect(last_value).to eq(@param_value)

				# Trigger task execution again
				@task.reenable
				downstream_task.reenable
				downstream_task.invoke
				expect(execution_count).to eq(1)
				expect(last_value).to eq(@param_value)

				# Generate and set the second value
				param_value_second = SecureRandom.hex 10
				ENV[@task.env_key] = param_value_second
				ENV['DEBUG'] && puts("param_value_second: #{param_value_second}")

				# Final trigger of task execution
				@task.reenable
				downstream_task.reenable
				downstream_task.invoke
				expect(execution_count).to eq(2)
				expect(last_value).to eq(param_value_second)

			end

		end

		describe 'with an encrypted param task' do

			before :each do

				@vault_secret = RakeParams::Utils.generate_secret
				ENV['VAULT_SECRET'] = @vault_secret
				ENV['DEBUG'] && puts("vault_secret: #{@vault_secret}")

				# Define an encrypted param task
				@task = RakeParams::ParamTask.define_task :expected_param do |config|
					config.sensitive = true
				end

			end

			it 'should resolve the defined param successfully if it has been provided encrypted in the environment' do

				# Add the needed environment variables.
				ENV["#{@task.env_key}_ENC"] = RakeParams::Utils.encrypt @param_value, @vault_secret

				# Run the task to resolve everything
				@task.invoke

				# Ensure that the hash file has been created.
				expect(File.exists?('.params/expected_param')).to eq(true)

				# Make sure the param resolves to its value.
				resolved_value = @task.resolve
				expect(resolved_value).to eq(@param_value)

			end

		end

	end

	describe 'with yaml configuration' do

		before :each do

			@yaml_config_file = "#{SecureRandom.hex 5}.yml"
			ENV['DEBUG'] && puts("yaml_config_file: #{@yaml_config_file}")

			# Set up the global configuration
			RakeParams::ParamTask.configure({
				yaml_config_file: @yaml_config_file
			})

			@param_value = SecureRandom.hex 10
			ENV['DEBUG'] && puts("param_value: #{@param_value}")

		end

		describe 'with a basic param task' do

			before :each do

				# Define the basic param task.
				@task = RakeParams::ParamTask.define_task :expected_param

			end

			it 'should respond to global yaml config task configuration' do

				# Make sure the task prerequisites contains the configured yaml config.
				expect(@task.prerequisites).to include(@yaml_config_file)

			end

			it 'should resolve if it has been provided simply in yaml config' do

				# Generate the yaml config.
				File.write @yaml_config_file, "---\nexpected_param: #{@param_value}"

				# Run the task to resolve everything
				@task.invoke

				# Ensure that the hash file has been created.
				expect(File.exists?('.params/expected_param')).to eq(true)

				# Make sure the param resolves to its value.
				resolved_value = @task.resolve
				expect(resolved_value).to eq(@param_value)

			end

			it 'should resolve if it has been provided nested in yaml config' do

				# Generate the yaml config.
				File.write @yaml_config_file, "---\nexpected:\n  param: #{@param_value}"

				# Run the task to resolve everything
				@task.invoke

				# Ensure that the hash file has been created.
				expect(File.exists?('.params/expected_param')).to eq(true)

				# Make sure the param resolves to its value.
				resolved_value = @task.resolve
				expect(resolved_value).to eq(@param_value)

			end

		end

		describe 'with an encrypted param task' do

			before :each do

				@vault_secret = RakeParams::Utils.generate_secret
				ENV['VAULT_SECRET'] = @vault_secret
				ENV['DEBUG'] && puts("vault_secret: #{@vault_secret}")

				# Define an encrypted param task
				@task = RakeParams::ParamTask.define_task :expected_param do |config|
					config.sensitive = true
				end

			end

			it 'should resolve the defined param if it has been provided encrypted in yaml config' do

				# Generate the yaml config.
				File.write @yaml_config_file, "---\nexpected_param: !vault #{RakeParams::Utils.encrypt @param_value, @vault_secret}"

				# Run the task to resolve everything
				@task.invoke

				# Ensure that the hash file has been created.
				expect(File.exists?('.params/expected_param')).to eq(true)

				# Make sure the param resolves to its value.
				resolved_value = @task.resolve
				expect(resolved_value).to eq(@param_value)

			end

		end

	end

end
