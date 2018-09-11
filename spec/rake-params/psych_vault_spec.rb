require 'securerandom'

require 'rake-params/psych_vault'
require 'rake-params/utils'

RSpec.describe RakeParams::PsychVault do

	before :each do
		@secret         = RakeParams::Utils.generate_secret
		@data_decrypted = SecureRandom.hex 10
		@data_encrypted = RakeParams::Utils.encrypt @data_decrypted, @secret
	end

	def parse(content)
		return RakeParams::PsychVault.parse(content) { @secret }
	end

	it 'does not decrypt data unless tagged' do
		result = parse "---\ndata: #{@data_encrypted}"
		expect(result['data']).to eq @data_encrypted
	end

	[ '!sym', '!vault' ].each do |tag|

		describe "when values are tagged with #{tag}" do

			it 'decrypts encrypted yaml scalars' do
				result = parse "---\ndata: #{tag} #{@data_encrypted}"
				expect(result['data']).to eq @data_decrypted
			end

			it 'decrypts values encrypted in arrays' do
				result = parse "---\ndata:\n  - #{tag} #{@data_encrypted}"
				expect(result['data'].first).to eq @data_decrypted
			end

			it 'decrypts values encrypted in nested hashes' do
				result = parse "---\ndata:\n  data2: #{tag} #{@data_encrypted}"
				expect(result['data']['data2']).to eq @data_decrypted
			end

		end

	end

end
