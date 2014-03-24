require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require File.expand_path(File.dirname(__FILE__) + '/../../config/boot')

describe RobotMaster::Priority do
  subject(:priority) {
    RobotMaster::Priority
  }
  
  context '#priority_class' do
    it 'critical' do
      expect(priority.priority_class(101)).to equal :critical
    end
    
    it 'high' do
      expect(priority.priority_class(1)).to equal :high
      expect(priority.priority_class(10)).to equal :high
      expect(priority.priority_class(100)).to equal :high
    end
    
    it 'default' do
      expect(priority.priority_class(0)).to equal :default
    end
    
    it 'low' do
      expect(priority.priority_class(-1)).to equal :low
    end
  end

  context '#priority_classes' do
    it 'critical' do
      expect(priority.priority_classes([101, 1000])).to eq [:critical]
    end
  
    it 'high' do
      expect(priority.priority_classes([1, 10, 100])).to eq [:high]
    end
  
    it 'default' do
      expect(priority.priority_classes([0])).to eq [:default]
    end
  
    it 'low' do
      expect(priority.priority_classes([-1, -10, -100, -1000])).to eq [:low]
    end

    it 'critical and low' do
      expect(priority.priority_classes([-100, 1000, -1, 150])).to eq [:critical, :low]
    end
  end

  context '#has_priority_items?' do
    it 'false' do
      [[], [0], [0, -1], [0, -100, 0], [:default, :low]].each do |i|
        expect(priority.has_priority_items?(i)).to be false
      end
    end
    it 'true' do
      [[1], [0, 1, 0], [0, 100, 1000], [:critical], [:high, :low]].each do |i|
        expect(priority.has_priority_items?(i)).to be true
      end
    end
  end
end