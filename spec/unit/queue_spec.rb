require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require File.expand_path(File.dirname(__FILE__) + '/../../config/boot')

describe RobotMaster::Queue do
  
  context '#queue_name' do
    it 'handles priority symbols' do
      RobotMaster::Priority::PRIORITIES.each do |priority|
        expect(described_class.queue_name('a:b:c-d', priority)).to eq "a_b_c-d_#{priority}"
      end
    end

    it 'does not handle illegal priority symbols' do
      expect { 
        described_class.queue_name('a:b:c', :bogus) 
      }.to raise_error(ArgumentError)
    end

    it 'handles qualified names' do
      expect(described_class.queue_name('a:b:c-d')).to eq 'a_b_c-d_default'
    end

    it 'does not handle unqualified' do
      expect { 
        described_class.queue_name('a-b') 
      }.to raise_error(ArgumentError)
    end

    it 'handles priority numbers' do
      expect(described_class.queue_name('a:b:c', -1)).to eq 'a_b_c_low'
      expect(described_class.queue_name('a:b:c', 0)).to eq 'a_b_c_default'
      expect(described_class.queue_name('a:b:c', 1)).to eq 'a_b_c_high'      
      expect(described_class.queue_name('a:b:c', 101)).to eq 'a_b_c_critical'
    end
  end
  
end