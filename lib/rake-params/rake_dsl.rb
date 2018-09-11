require 'rake/dsl_definition'

require_relative 'param_task'

module RakeParams

	module RakeDsl

		# Configures and initialises the param task subsystem.
		# @param  config [Hash]                               Configuration option settings.
		# @option config [String]         :hash_dir           The directory that param hashes are stored in. Defaults to +.params+.
		# @option config [String, Symbol] :vault_secret_param The name of the vault encryption secret param. Defaults to +:vault_secret+.
		# @option config [Array<String>]  :vault_env_suffixes The suffixes used to search for encrypted environment variables. Defaults to +['_ENC','_SYM','_VAULT']+.
		# @option config [String, nil]    :yaml_config_file   The path to a config file containing any and all param values. Defaults to +nil+.
		def param_init(config = {})
			ParamTask.configure(config)
		end

		# Creates a new param task where the block is used to configure the task if needed. If the task has already been defined, it returns the task of the param if possible.
		# @param  name   [String]             The name of the template task. Should be the file to render.
		# @param  config [Hash]               Any configuration needed for the task.
		# @option config [String]  :env_key   The environment variable key to use during value resolution. Defaults to the uppercase of the task name.
		# @option config [String]  :hash_file The file to store the value hash in. Defaults to the task name.
		# @option config [Boolean] :sensitive Whether the value might be encrypted. Defaults to false.
		# @option config [String]  :default   If no other methods succeed, use this value for the param.
		# @param  block  [Proc]               An additional action that gets run during task execution.
		# @return        [ParamTask]          The param task
		def param(name, config = {}, &block)
			return Rake.application.lookup(name) \
					|| ParamTask.define_task(name, config, &block)
		end

	end

end

# Monkey-patch the functions into the rake dsl
Rake::DSL.include RakeParams::RakeDsl

# Refresh the root context
self.extend Rake::DSL
