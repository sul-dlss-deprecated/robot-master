require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require File.expand_path(File.dirname(__FILE__) + '/../../config/boot')

describe RobotMaster::Queue do
  let(:threshold) { 100 }
  let(:step) { 'a:b:c' }
  
  context '#queue_name' do
    it 'handles symbols' do
      %w{* a aA a-A a-b A AA AAA AAAA AAAAA AAAAAA}.map(&:to_sym).each do |lane|
        expect(described_class.queue_name('a:b:c-d', lane)).to eq "a_b_c-d_#{lane}"
      end
    end

    it 'handles qualified names' do
      expect(described_class.queue_name('a:b:c-d')).to eq 'a_b_c-d_default'
    end

    it 'does not handle unqualified' do
      expect { 
        described_class.queue_name('a-b') 
      }.to raise_error(ArgumentError)
    end

    it 'does not handle malformed names' do
      %w{A_B A@B}.each do |lane|
        expect { 
          described_class.queue_name(step, lane) 
        }.to raise_error(ArgumentError)
      end
    end

    it 'handles numbers' do
      expect(described_class.queue_name(step, -1)).to eq 'a_b_c_-1'
      expect(described_class.queue_name(step, 0)).to eq 'a_b_c_0'
      expect(described_class.queue_name(step, 1)).to eq 'a_b_c_1'      
      expect(described_class.queue_name(step, 99)).to eq 'a_b_c_99'
    end
  end
  
  context '#empty_slots' do
    before do
      Resque.redis = MockRedis.new
    end
    
    it 'illegal arguments' do
      expect { described_class.empty_slots }.to raise_error(ArgumentError)
    end
    
    it 'no queue' do
      expect(described_class.empty_slots(step)).to eq 100
    end
    
    it 'queue single job' do
      Resque.enqueue_to(described_class.queue_name(step), 'Foo')
      expect(described_class.empty_slots(step, :default, 1)).to eq 0
    end

    it 'queue threshold jobs' do
      threshold.times do |i|
        Resque.enqueue_to(described_class.queue_name(step), 'Foo')
      end
      expect(described_class.empty_slots(step)).to eq 0
    end

    it 'queue not-quite threshold jobs' do
      (threshold-1).times do |i|
        Resque.enqueue_to(described_class.queue_name(step), 'Foo')
      end
      expect(described_class.empty_slots(step)).to eq 1
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
      r = described_class.enqueue(step, 'aa111bb2222')
      expect(r[:queue]).to eq q
      expect(r[:klass]).to eq 'Robots::ARepo::B::C'
      expect(Resque.size(q)).to eq 1
      expect(Resque.peek(q)).to eq({
        "class"=>"Robots::ARepo::B::C", 
        "args"=>["aa111bb2222"]
        })
    end
    
    it 'N jobs' do
      n = threshold
      q = described_class.queue_name(step)
      expect(Resque.size(q)).to eq 0
      n.times do |i|
        described_class.enqueue(step, 'aa111bb2222')
        expect(Resque.size(q)).to eq (i+1)
      end
      
      n.times do |i|
        expect(Resque.pop(q)).to eq({
          "class"=>"Robots::ARepo::B::C", 
          "args"=>["aa111bb2222"]
          })
      end
      expect(Resque.size(q)).to eq 0
    end
    
  end
end