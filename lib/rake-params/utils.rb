require 'sym'

module RakeParams

	module Utils

		class Sym
			include ::Sym
		end

		SYM = Sym.new

		private_constant :SYM, :Sym

		def self.encrypt(content, secret)
			return SYM.encr content, secret
		end

		def self.decrypt(content, secret)
			return SYM.decr content, secret
		end

		def self.generate_secret()
			return Sym.create_private_key
		end

		# Resolves a given input if it's a proc, or just returns it if not. A proc calling context is optional.
		# @param input   [Proc, T] The proc that resolves to input, or raw input.
		# @param context [*]       Any context information to pass to the proc.
		# @return        [T]       The resolved value of the proc, or the value if +input+ isn't a proc.
		def self.unproc(input, *context)
			return ( not input.nil? and input.respond_to? :call ) \
					? input.call(*context) \
					: input
		end

	end

end
