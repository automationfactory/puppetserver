require 'spec_helper'
describe 'lamp' do
  context 'with default values for all parameters' do
    it { should contain_class('lamp') }
  end
end
