require 'securerandom'

require 'rake-params/utils'

describe RakeParams::Utils do

	describe :unproc do

		before :each do
			@secret = SecureRandom.hex 10
		end

		it 'should resolve a hash to itself' do
			hash = { value: @secret }
			result = RakeParams::Utils.unproc hash
			expect(result).to be hash
		end

		it 'should resolve a string to itself' do
			result = RakeParams::Utils.unproc @secret
			expect(result).to eq @secret
		end

		it 'should resolve a proc to its output' do
			block = proc { @secret }
			result = RakeParams::Utils.unproc block
			expect(result).to eq @secret
		end

		it 'should resolve a proc with context to its output' do
			block = proc { |data| data[:secret] }
			result = RakeParams::Utils.unproc block, { secret: @secret }
			expect(result).to eq @secret
		end

	end

end
