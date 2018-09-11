# Rake Params
[![Build Status](https://travis-ci.org/aetheric/rake-params.svg?branch=master)](https://travis-ci.org/aetheric/rake-params)
[![Coverage Status](https://coveralls.io/repos/github/aetheric/rake-params/badge.svg?branch=master)](https://coveralls.io/github/aetheric/rake-params?branch=master)

A custom rake task that provides complex parameter functionality.

## Usage

Add it to your gemfile:

	gem 'rake-params'

Require it in your rakefile:

	require 'rake-params'

Initialise the configuration:

	# Minimal required
	param_init

	# Customise options (defaults listed here)
	param_init({
		hash_dir:           '.params',
		vault_secret_param: :vault_secret,
		vault_env_suffixes: [ '_ENC', '_SYM', '_VAULT' ],
		yaml_config_file:   nil,
	})

Define a parameter:

	# Minimal required
	param :branch_name

	# Customise options (defaults listed here)
	param :branch_name, {
		env_key:   'BRANCH_NAME',
		hash_file: '.params/branch_name',
		sensitive: false,
		default:   nil
	}

	# param saved to variable
	$branch_name = param :branch_name

Use it as a dependency:

	# Reference by symbol
	task :print => [ :branch_name ] do
		puts param(:branch_name).resolve
	end

	# Reference by variable
	task :print => [ $branch_name ] do
		puts $branch_name.resolve
	end
