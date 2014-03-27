require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require File.expand_path(File.dirname(__FILE__) + '/../../config/boot')

describe RobotMaster::Priority do
  
  it 'expected methods' do
    %w{
      priority_class 
      priority_classes 
      has_priority_items?
    }.map(&:to_sym).each do |k|
      expect(described_class.respond_to?(k)).to be_true
    end
  end
  
  it 'illegal arguments' do
    expect { 
      described_class.has_priority_items?(%w{critical high}) 
    }.to raise_error(ArgumentError)
  end

  it 'wrong type' do
    expect { 
      described_class.has_priority_items?('critical') 
    }.to raise_error(NoMethodError)
  end
  
  context '#priority_class' do
    it 'critical' do
      expect(described_class.priority_class(101)).to equal :critical
      expect(described_class.priority_class(2**32-1)).to equal :critical
    end
    
    it 'high' do
      expect(described_class.priority_class(1)).to equal :high
      expect(described_class.priority_class(10)).to equal :high
      expect(described_class.priority_class(100)).to equal :high
    end
    
    it 'default' do
      expect(described_class.priority_class(0)).to equal :default
    end
    
    it 'low' do
      expect(described_class.priority_class(-1)).to equal :low
      expect(described_class.priority_class(-2**32-1)).to equal :low
    end
  end

  context '#priority_classes' do
    it 'critical' do
      expect(described_class.priority_classes([101, 1000])).to eq [:critical]
    end
  
    it 'high' do
      expect(described_class.priority_classes([1, 10, 100])).to eq [:high]
    end
  
    it 'default' do
      expect(described_class.priority_classes([0])).to eq [:default]
    end
  
    it 'low' do
      expect(described_class.priority_classes([-1, -10, -100, -1000])).to eq [:low]
    end

    it 'critical and low' do
      expect(described_class.priority_classes([-100, 1000, -1, 150])).to eq [:critical, :low]
    end
  end

  context '#has_priority_items?' do
    it 'false' do
      [[], [0], [0, -1], [0, -100, 0], [0.0], [:default, :low]].each do |i|
        expect(described_class.has_priority_items?(i)).to be_false
      end
    end
    it 'true' do
      [[1], [0, 1, 0], [0, 100, 1000], [10.1], [:critical], [:high, :low]].each do |i|
        expect(described_class.has_priority_items?(i)).to be_true
      end
    end
  end
end