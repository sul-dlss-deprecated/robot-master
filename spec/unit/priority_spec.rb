require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require File.expand_path(File.dirname(__FILE__) + '/../../config/boot')

describe RobotMaster::Priority do
  subject {
    RobotMaster::Priority
  }
  
  it 'expected methods' do
    # expect(subject.respond_to?(:priority_class)).to be_true
    # expect(subject.respond_to?(:priority_classes)).to be_true
    # expect(subject.respond_to?(:has_priority_items?)).to be_true
  end
  
  context '#priority_class' do
    it 'critical' do
      expect(subject.priority_class(101)).to equal :critical
    end
    
    it 'high' do
      expect(subject.priority_class(1)).to equal :high
      expect(subject.priority_class(10)).to equal :high
      expect(subject.priority_class(100)).to equal :high
    end
    
    it 'default' do
      expect(subject.priority_class(0)).to equal :default
    end
    
    it 'low' do
      expect(subject.priority_class(-1)).to equal :low
    end
  end

  context '#priority_classes' do
    it 'critical' do
      expect(subject.priority_classes([101, 1000])).to eq [:critical]
    end
  
    it 'high' do
      expect(subject.priority_classes([1, 10, 100])).to eq [:high]
    end
  
    it 'default' do
      expect(subject.priority_classes([0])).to eq [:default]
    end
  
    it 'low' do
      expect(subject.priority_classes([-1, -10, -100, -1000])).to eq [:low]
    end

    it 'critical and low' do
      expect(subject.priority_classes([-100, 1000, -1, 150])).to eq [:critical, :low]
    end
  end

  context '#has_priority_items?' do
    it 'false' do
      [[], [0], [0, -1], [0, -100, 0], [0.0], [:default, :low]].each do |i|
        expect(subject.has_priority_items?(i)).to be_false
      end
    end
    it 'true' do
      [[1], [0, 1, 0], [0, 100, 1000], [10.1], [:critical], [:high, :low]].each do |i|
        expect(subject.has_priority_items?(i)).to be_true
      end
    end
    
    it 'illegal arguments' do
      expect { subject.has_priority_items?(%w{critical high}) }.to raise_error(ArgumentError)
    end
  end
end