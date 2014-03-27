require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require File.expand_path(File.dirname(__FILE__) + '/../../config/boot')

describe RobotMaster::Queue do
  let(:threshold) { 100 }
  let(:step) { 'a:b:c' }
  
  context '#queue_name' do
    it 'handles priority symbols' do
      RobotMaster::Priority::PRIORITIES.each do |priority|
        expect(described_class.queue_name('a:b:c-d', priority)).to eq "a_b_c-d_#{priority}"
      end
    end

    it 'does not handle illegal priority symbols' do
      expect { 
        described_class.queue_name(step, :bogus) 
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
      expect(described_class.queue_name(step, -1)).to eq 'a_b_c_low'
      expect(described_class.queue_name(step, 0)).to eq 'a_b_c_default'
      expect(described_class.queue_name(step, 1)).to eq 'a_b_c_high'      
      expect(described_class.queue_name(step, 101)).to eq 'a_b_c_critical'
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
      described_class.queue_empty?(step).should be_true
    end
    
    it 'queue single job' do
      Resque.enqueue_to(described_class.queue_name(step), 'Foo')
      described_class.queue_empty?(step, :default, 1).should be_false
    end

    it 'queue threshold jobs' do
      threshold.times do |i|
        Resque.enqueue_to(described_class.queue_name(step), 'Foo')
      end
      described_class.queue_empty?(step).should be_false
    end

    it 'queue not-quite threshold jobs' do
      (threshold-1).times do |i|
        Resque.enqueue_to(described_class.queue_name(step), 'Foo')
      end
      described_class.queue_empty?(step).should be_true
    end
  end
  
  context '#enqueue' do
    before do
      Resque.redis = MockRedis.new
    end
    
    it 'no jobs' do
      q = described_class.queue_name(step)
      expect(Resque.size(q)).to eq 0
    end
    
    it 'single job' do
      q = described_class.queue_name(step)
      expect(Resque.size(q)).to eq 0
      described_class.enqueue(step, 'aa111bb2222', :default)
      expect(Resque.size(q)).to eq 1
      expect(Resque.peek(q)).to eq({
        "class"=>"Robots::A::B::C", 
        "args"=>["aa111bb2222"]
        })
    end
    
    it 'N jobs' do
      n = threshold
      q = described_class.queue_name(step)
      expect(Resque.size(q)).to eq 0
      n.times do |i|
        described_class.enqueue(step, 'aa111bb2222', :default)
        expect(Resque.size(q)).to eq (i+1)
      end
      
      n.times do |i|
        expect(Resque.pop(q)).to eq({
          "class"=>"Robots::A::B::C", 
          "args"=>["aa111bb2222"]
          })
      end
      expect(Resque.size(q)).to eq 0
    end
    
  end
end