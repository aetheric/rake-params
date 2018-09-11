require 'psych'

require_relative 'utils'

module RakeParams

	# Psych handler used to decrypt data embedded in yaml.
	class PsychVault < Psych::Handlers::DocumentStream

		# The yaml tags used to identify encrypted content.
		# @type [Array<String>]
		@@tag_names = [ '!vault', '!sym' ]

		# Provides access to the yaml tags used to identify encrypted data.
		# @return [Array<String>] The current list of tag names.
		def self.tag_names
			return @@tag_names
		end

		# Sets the tags used to read encrypted data to whatever is provided. Note, each entry must include the '!'
		# prefix, as it isn't prepended during yaml processing.
		# @param [Array<String>] value The new list of yaml tags.
		def self.tag_names=(value)
			@@tag_names = value
		end

		# Shortcut to create and invoke parser.
		# @param  [String] content         The YAML string content to parse.
		# @param  [Proc]   secret_provider Used to acquire the decryption secret.
		# @return [Hash]                   The parsed and decrypted data.
		def self.parse(content, &secret_provider)

			# Set up the document handler.
			handler = self.new(secret_provider) do |document|
				# Note: This actually breaks directly from the method.
				return document.to_ruby
			end

			# Set-up the parser itself, using the handler.
			parser = Psych::Parser.new(handler)

			# Trigger parsing of the content.
			parser.parse content

		end

		# Shortcut to parse a file directly.
		# @param  [String] file            The file to read to yaml.
		# @param  [Proc]   secret_provider Used to acquire the decryption secret.
		# @return [Hash]                   The parsed and decrypted data.
		def self.parse_file(file, &secret_provider)
			content = File.read file
			return self.parse content, &secret_provider
		end

		# Creates a new instance given a decryption secret provider.
		# @param [Proc] secret_provider Provides a decryption secret when called.
		# @param [Proc] on_complete     Called when the handler is done, with the document.
		def initialize(secret_provider, &on_complete)
			super &on_complete
			@secret_provider = secret_provider
		end

		# @param [String]     value  The string value of the scalar.
		# @param [String|nil] anchor An associated anchor or nil.
		# @param [String|nil] tag    An associated tag or nil.
		# @param [Boolean]    plain  A boolean value.
		# @param [Boolean]    quoted A boolean value.
		# @param [Integer]    style  An integer indicating the string style.
		def scalar(value, anchor, tag, plain, quoted, style)

			# If the tag is recognised, decrypt the value.
			if @@tag_names.include? tag
				secret = @secret_provider.call
				value  = Utils.decrypt value, secret
				tag    = nil
			end

			# Let the rest of the hard work be handled elsewhere.
			return super value, anchor, tag, plain, quoted, style

		end

	end

end
