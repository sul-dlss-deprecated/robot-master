require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require File.expand_path(File.dirname(__FILE__) + '/../../config/boot')

describe RobotMaster::Queue do
  subject {
    RobotMaster::Queue
  }
  
  context '#queue_name' do
    let(:priorities) {  
      %w{critical high default low}.map(&:to_sym)
    }

    it 'handles priority symbols' do
      priorities.each do |priority|
        expect(subject.queue_name('dor:accessionWF:foo-bar', priority)).to eq "dor_accessionWF_foo-bar_#{priority}"
      end
    end

    it 'does not handle unqualified' do
      expect { subject.queue_name('foo-bar') }.to raise_error(ArgumentError)
    end

    it 'handles priority numbers' do
      expect(subject.queue_name('dor:accessionWF:foo-bar', 0)).to eq 'dor_accessionWF_foo-bar_default'
      expect(subject.queue_name('dor:accessionWF:foo-bar', 1)).to eq 'dor_accessionWF_foo-bar_high'      
    end

    it 'handles qualified names' do
      expect(subject.queue_name('a:b:c')).to eq 'a_b_c_default'      
      expect(subject.queue_name('a:b:c-d')).to eq 'a_b_c-d_default'      
    end
  end
  
end