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
  
  context '#queue_empty?' do
    before do
      Resque.redis = MockRedis.new
    end
    
    it 'illegal arguments' do
      expect { described_class.queue_empty? }.to raise_error(ArgumentError)
    end
    
    it 'no queue' do
      described_class.queue_empty?('a:b:c', 0).should be_true
    end
    
    it 'queue single job' do
      Resque.enqueue_to(described_class.queue_name('a:b:c'), 'Foo')
      described_class.queue_empty?('a:b:c', 0, 1).should be_false
    end

    it 'queue threshold jobs' do
      100.times do |i|
        Resque.enqueue_to(described_class.queue_name('a:b:c'), 'Foo')
      end
      described_class.queue_empty?('a:b:c', 0).should be_false
    end

    it 'queue not-quite threshold jobs' do
      99.times do |i|
        Resque.enqueue_to(described_class.queue_name('a:b:c'), 'Foo')
      end
      described_class.queue_empty?('a:b:c', 0).should be_true
    end
  end
  
end