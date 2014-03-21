require File.expand_path(File.dirname(__FILE__) + '/../../config/boot')
require 'rspec'
require 'spec_helper'

describe RobotMaster do
  before(:each) do
    @subject = RobotMaster::Workflow.new('dor', 'accessionWF')
  end
  
  it '#queue_name' do
    %w{critical high default low}.each do |priority|
      @subject.queue_name('foo-bar', priority.to_sym).should == 'dor_accessionWF_foo-bar_' + priority
    end
    @subject.queue_name('foo-bar', 0) == 'dor_accessionWF_foo-bar_default'
    @subject.queue_name('dor:someWF:foo-bar', -1) == 'dor_someWF_foo-bar_low'
  end
  
  it '#priority_class' do
    @subject.priority_class(101).should == :critical
    @subject.priority_class(1).should == :high
    @subject.priority_class(0).should == :default
    @subject.priority_class(-1).should == :low
  end
  
  it '#prority_classes' do
    @subject.priority_classes([100, -100, 1000, -1, 99, 150]).should == [:critical, :high, :low]
    @subject.priority_classes([0, 0]).should == [:default]
  end
  
  it '#has_priority_items?' do
    @subject.has_priority_items?([0]).should == false
    @subject.has_priority_items?([0, -1]).should == false
    @subject.has_priority_items?([1]).should == true
    @subject.has_priority_items?([100, 0, -100]).should == true
  end
  
  it '#parse_process_node -- with prereqs' do
    doc = Nokogiri::XML('
     <process name="remediate-object" sequence="6">
       <label>Ensure object conforms to latest DOR standards and schemas</label>
       <prereq>content-metadata</prereq>
       <prereq>descriptive-metadata</prereq>
       <prereq>technical-metadata</prereq>
       <prereq>rights-metadata</prereq>
      </process>')
    @subject.parse_process_node(doc.root).should == {
      :name => "dor:accessionWF:remediate-object",
    :prereq => [
         "dor:accessionWF:content-metadata",
         "dor:accessionWF:descriptive-metadata",
         "dor:accessionWF:technical-metadata",
         "dor:accessionWF:rights-metadata"
      ],
      :skip => false
    }
  end
  
  it '#parse_process_node -- with skip queue' do
    doc = Nokogiri::XML('
     <process name="foo-bar" sequence="1" skip-queue="true">
       <prereq>content-metadata</prereq>
      </process>')
    @subject.parse_process_node(doc.root).should == {
      :name => "dor:accessionWF:foo-bar",
    :prereq => [ "dor:accessionWF:content-metadata" ],
      :skip => true
    }
  end
  
  it '#parse_process_node -- with qualified name' do
    doc = Nokogiri::XML('
     <process name="foo-bar" sequence="1">
       <prereq>dor:assemblyWF:jp2-create</prereq>
      </process>')
    @subject.parse_process_node(doc.root).should == {
      :name => "dor:accessionWF:foo-bar",
    :prereq => [ "dor:assemblyWF:jp2-create" ],
      :skip => false
    }
  end

end