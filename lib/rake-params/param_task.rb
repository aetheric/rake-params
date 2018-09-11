require 'rake'
require 'yaml'

require_relative 'utils'
require_relative 'psych_vault'

module RakeParams

	# A type of task used for collecting config information and not only making it available during task
	# execution, but acting as a prerequisite that will invalidate downstream tasks if the config value
	# changes. Hooks into Sym to decrypt any data specified as prerequisites.
	class ParamTask < Rake::FileTask
		include ::Sym

		# <editor-fold desc="Global Config and Definition">

		# Stores configuration used for all ParamTask instances created.
		class GlobalConfig

			# The directory that param hashes get stored. Defaults to '.params'
			attr_accessor :hash_dir

			# The name of the encryption secret param task. Defaults to 'vault_secret'.
			attr_accessor :vault_secret_param

			# The suffixes that encrypted environment variables can use. Defaults to '_ENC', '_SYM', and '_VAULT'.
			attr_accessor :vault_env_suffixes

			# The config file that parameter values can be drawn from. Defaults to nil.
			attr_accessor :yaml_config_file

			def initialize
				@hash_dir           = '.params'
				@vault_secret_param = :vault_secret
				@vault_env_suffixes = [ '_ENC', '_SYM', '_VAULT' ]
				@yaml_config_file   = nil
			end

		end

		private_constant :GlobalConfig

		# This needs to be run before any ParamTask instances get
		# @param [Hash] config The configuration to apply to param task usage.
		def self.configure(config = {})

			raise 'Already configured global ParamTask usage.' \
					if defined?(@@config) && @@rake_id == Rake.application.object_id

			# This is stored to allow reconfiguration when the rake app changes (in testing).
			@@rake_id = Rake.application.object_id

			# Initialise a new config and yield it for use.
			@@config = GlobalConfig.new

			# Find config hashes in arguments and use them first
			@@config.hash_dir           = config[:hash_dir]           if config.has_key? :hash_dir
			@@config.vault_secret_param = config[:vault_secret_param] if config.has_key? :vault_secret_param
			@@config.vault_env_suffixes = config[:vault_env_suffixes] if config.has_key? :vault_env_suffixes
			@@config.yaml_config_file   = config[:yaml_config_file]   if config.has_key? :yaml_config_file

			# Set-up hash-dir directory task
			Rake::FileTask.define_task @@config.hash_dir do |task|
				FileUtils.mkdir_p task.name
			end

			# Set-up vault-pass param task
			ParamTask.define_task @@config.vault_secret_param, { default: '' }

			# If the yaml config was defined, add it as a FileTask
			Rake::FileTask.define_task @@config.yaml_config_file \
					if @@config.yaml_config_file

		end

		# Defines a ParamTask given a name and configuration.
		# @param  [String]    name   The name of the template task. Should be the file to render.
		# @param  [Hash]      config Any configuration needed for the task.
		# @param  [Proc]      block  An additional action that gets run during task execution.
		# @return [ParamTask]        The param task
		def self.define_task(name, config = {}, &block)

			# Prevent param tasks from being defined before global configuration set.
			raise 'You need to run ParamTask.configure before defining tasks.' \
					unless defined?(@@config) && @@rake_id == Rake.application.object_id

			# Create the task, return early if it isn't what we want.
			# The supplied config block gets added as an action by default, so replace it with a dummy block.
			task = super name, config[:args] || [] => config[:dependencies] || [], &block
			return task unless task.is_a? ParamTask

			# Find hash configuration if possible, set any config specified.
			task.env_key   = config[:env_key]   if config.has_key? :env_key
			task.hash_file = config[:hash_file] if config.has_key? :hash_file
			task.sensitive = config[:sensitive] if config.has_key? :sensitive
			task.default   = config[:default]   if config.has_key? :default

			# Yield the block for configuration
			block&.call task

			# Make sure prerequisites include the hash directory
			task.enhance [ @@config.hash_dir ]

			# Add yaml config as a prerequisite if defined
			task.enhance [ @@config.yaml_config_file ] \
					if @@config.yaml_config_file

			return task

		end

		# </editor-fold>

		# <editor-fold desc="Dependency Trigger Calculations">

		# The param execution can be considered unneeded if the ENV var is present, and has the same value as the
		# previous execution.
		# @return [Boolean] Whether the task needs to be executed.
		def needed?

			# Needed if the current env value is missing.
			return true unless ENV.has_key? env_key

			# Needed if the hash file doesn't exist.
			return true unless File.exists? hash_file

			# Needed if the hash values differ
			return true unless hash_expected(false) == hash_existing

			# Needed if any prerequisites are out-of-date
			return true if out_of_date? timestamp

			# Needed if an override has been provided
			return true if @application.options.build_all

			# Otherwise, the task doesn't need execution.
			return false

		end

		# The timestamp should be that of the last execution
		# @return [Time|LateTime] The hash file timestamp, or a time that's always in the future.
		def timestamp
			return File.exists?(hash_file) \
					? File.mtime(hash_file) \
					: Rake::LATE
		end

		# </editor-fold>

		# <editor-fold desc="Execution and Resolution">

		# When the task actually runs, it should attempt to resolve the variable, and hash the result.
		def execute(*args)
			super

			# Resolve the current value.
			value = resolve false

			# If the value is nil, make sure the hash file doesn't exist, then throw an error.
			if value.nil?
				File.delete hash_file if File.exists? hash_file
				raise ArgumentError, "The parameter '#{name}' has not been provided or defaulted."
			end

			# Write the hash of the current value to file.
			File.write hash_file, hash_expected

		end

		# Resolves the value of the parameter from a number of potential sources, from most to least likely.
		# @param  [Boolean] use_cache The cached value is reset with a fresh resolution if true.
		# @return [String]            The value of the parameter, or nil if not found anywhere.
		def resolve(use_cache = true)

			# Use the cached value if possible and desired.
			return @value if @value && use_cache

			# Resolve the value in order of difficulty / probability of being set.
			@value = ENV[env_key] || resolve_encrypted || resolve_yaml || Utils.unproc(default, self)

			# Return the resolved value or nil if unresolved.
			return @value

		end

		# Attempts to resolve an encrypted environment variable and decrypt it using the vault secret. If the task
		# isn't marked as sensitive, this will always immediately return nil to avoid issues with the vault secret
		# not being marked as a dependency.
		# @return [String] The encrypted value, or nil if unresolved.
		def resolve_encrypted

			# If not a 'sensitive' param, there is no encryption
			return nil unless @sensitive

			# First find the appropriate suffix, and if not found, just return nil.
			suffix = @@config.vault_env_suffixes.find { |suffix| ENV.has_key? "#{env_key}#{suffix}" }
			return nil if suffix.nil?

			# Get the encrypted value
			encrypted = ENV["#{env_key}#{suffix}"]

			# Return the decrypted value
			return decr encrypted, vault_secret

		end

		# Used to determine whether the yaml cache is intact, or needs to be reloaded.
		# @return [Boolean] Whether the cache can be used.
		def yaml_cache_valid?

			# Invalid if not set at all.
			return false unless defined?(@@yaml_config)

			# Invalid if files differ
			return false unless @@yaml_config_file == @@config.yaml_config_file

			# Invalid if sensitivity is required, but not decrypted
			return false unless @@yaml_config_decrypted || !@sensitive

			# Cache is valid.
			return true

		end

		# Resolves the param from an available yaml config file, decrypting it if necessary.
		# @return [String] The value, or nil if not resolved.
		def resolve_yaml

			# Store this to make subsequent access clearer.
			yaml_config_file = @@config.yaml_config_file

			# Don't do anything if the yaml config isn't set, or doesn't exist.
			return nil unless yaml_config_file && File.exists?(yaml_config_file)

			# Quick function defined for actually resolving the value from the yaml config.
			def do_resolve() @@yaml_config[name] || @@yaml_config.dig(*name.split('_')) end

			# Use the cached loaded yaml if it's available and decrypted if necessary.
			return do_resolve if yaml_cache_valid?

			unless @sensitive
				# Read yaml without attempting to decrypt anything.
				@@yaml_config = YAML.load_file yaml_config_file
				@@yaml_config_file = @@config.yaml_config_file
				@@yaml_config_decrypted = false
				return do_resolve
			end

			# Read and parse the yaml, utilising the available vault secret.
			@@yaml_config = PsychVault.parse_file(yaml_config_file) { vault_secret }
			@@yaml_config_file = @@config.yaml_config_file
			@@yaml_config_decrypted = true
			return do_resolve

		end

		protected :resolve_encrypted,
		          :resolve_yaml,
		          :yaml_cache_valid?

		# </editor-fold>

		# <editor-fold desc="Local Config and Definition">

		def initialize(name, app)
			super
		end

		# Set up task properties
		attr_accessor :env_key, :hash_file, :sensitive, :default

		# The key used to read the parameter from [ENV].
		# @return [String] The environment variable key for this param.
		def env_key
			return @env_key ||= self.name.upcase
		end

		# The file used to store hashed variable information.
		# @return [String] The path of the hash data file.
		def hash_file
			return @hash_file ||= Pathname.new(@@config.hash_dir).join(name).to_s
		end

		# Whether the parameter stored in ENV, config, etc is encrypted.
		# @param [Boolean] value
		def sensitive=(value)

			if value == @sensitive
				# No changes needed.
				return
			end

			# Update value
			@sensitive = value

			if @sensitive
				# If turning-on sensitivity, ensure the vault_secret param is a prerequisite.
				@prerequisites << @@config.vault_secret_param

			else
				# If turning-off sensitivity, ensure vault_secret is _not_ a prerequisite.
				@prerequisites.delete_element @@config.vault_secret_param
			end

		end

		# @return [Boolean] Whether this param is sensitive. Defaults to false.
		def sensitive
			return @sensitive ||= false
		end

		# Fetches the contents of the hash stored in the hash file if it exists.
		# @return [String] The stored hash, or nil if the file doesn't exist.
		def hash_existing
			return File.exists?(hash_file) \
					? File.read(hash_file) \
					: nil
		end

		# Grabs the currently stored environment variable and hashes it.
		# @param  [Boolean] use_cache The cached value is reset with a fresh resolution if true.
		# @return [String] The has of the current value, or nil if it isn't available.
		def hash_expected(use_cache = true)
			value = resolve use_cache
			return value \
					? Digest::SHA1.hexdigest(value) \
					: nil
		end

		# Retrieves the vault_secret value from the vault secret param task if available.
		# @return [String] The vault secret.
		def vault_secret

			# Don't attempt to resolve if not a task prerequisite.
			return nil unless @sensitive

			# Resolve the task from the rake context
			param = @@config.vault_secret_param
			task  = @application.lookup param

			# Call 'resolve' on the secret param.
			return task.resolve

		end

		protected :hash_existing,
		          :hash_expected,
		          :vault_secret

		# </editor-fold>

	end

end
