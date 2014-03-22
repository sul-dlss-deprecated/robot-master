require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require File.expand_path(File.dirname(__FILE__) + '/../../config/boot')

describe RobotMaster do
  let(:priorities) {  
    %w{critical high default low}.map(&:to_sym)
  }
  subject(:master) {
    RobotMaster::Workflow.new('dor', 'accessionWF')
  }
  
  it '#queue_name' do
    priorities.each do |priority|
      expect(master.queue_name('foo-bar', priority)).to eq "dor_accessionWF_foo-bar_#{priority}"
    end
    expect(master.queue_name('foo-bar', 0)).to eq 'dor_accessionWF_foo-bar_default'
    expect(master.queue_name('dor:someWF:foo-bar', -1)).to eq 'dor_someWF_foo-bar_low'
  end
  
  context '#priority_class' do
    it 'critical' do
      expect(master.priority_classes([101, 1000])).to eq [:critical]
    end
    
    it 'high' do
      expect(master.priority_classes([1, 10, 100])).to eq [:high]
    end
    
    it 'default' do
      expect(master.priority_class(0)).to equal :default
    end
    
    it 'low' do
      expect(master.priority_classes([-1, -10, -100, -1000])).to eq [:low]
    end
  
    it 'critical and low' do
      expect(master.priority_classes([-100, 1000, -1, 150])).to eq [:critical, :low]
    end
  end
  
  context '#has_priority_items?' do
    it 'false' do
      [[0], [0, -1], [0, -100, 0]].each do |i|
        expect(master.has_priority_items?(i)).to be false
      end
    end
    it 'true' do
      [[1], [0, 1, 0], [0, 100, 1000]].each do |i|
        expect(master.has_priority_items?(i)).to be true
      end
    end
  end
  
  context '#parse_process_node' do
    it 'empty' do
      doc = Nokogiri::XML('<process name="initiate"/>')
      expect(master.parse_process_node(doc.root)[:name]).to eq 'dor:accessionWF:initiate'
      expect(master.parse_process_node(doc.root)[:skip]).to be false
    end

    it 'waiting' do
      doc = Nokogiri::XML('<process name="initiate" status="waiting"/>')
      expect(master.parse_process_node(doc.root)[:skip]).to be false
    end

    it 'completed' do
      doc = Nokogiri::XML('<process name="initiate" status="completed"/>')
      expect(master.parse_process_node(doc.root)[:skip]).to be true
    end

    it 'skip-queue' do
      doc = Nokogiri::XML('<process name="initiate" skip-queue="true"/>')
      expect(master.parse_process_node(doc.root)[:skip]).to be true
    end

    it 'skip-queue false' do
      doc = Nokogiri::XML('<process name="initiate" skip-queue="false"/>')
      expect(master.parse_process_node(doc.root)[:skip]).to be false
    end
  
    context "single prereq" do
      let(:doc) {
        Nokogiri::XML('
         <process name="remediate-object">
           <prereq>content-metadata</prereq>
          </process>'
        )
      }
      it 'should' do
        expect(master.parse_process_node(doc.root)[:prereq]).to eq [
             'dor:accessionWF:content-metadata'
          ]
      end
    end
  
    context 'multiple prereqs' do
      let(:doc) {
        Nokogiri::XML('
         <process name="remediate-object">
           <prereq>content-metadata</prereq>
           <prereq>descriptive-metadata</prereq>
           <prereq>technical-metadata</prereq>
           <prereq>rights-metadata</prereq>
          </process>'
        )
      }
      it 'should' do
        expect(master.parse_process_node(doc.root)[:prereq]).to eq [
             'dor:accessionWF:content-metadata',
             'dor:accessionWF:descriptive-metadata',
             'dor:accessionWF:technical-metadata',
             'dor:accessionWF:rights-metadata'
          ]
      end
    end
    
    it 'with qualified name' do
      doc = Nokogiri::XML('
       <process name="foo-bar">
         <prereq>dor:assemblyWF:jp2-create</prereq>
        </process>')
      expect(master.parse_process_node(doc.root)[:name]).to eq 'dor:accessionWF:foo-bar'
      expect(master.parse_process_node(doc.root)[:prereq]).to eq ['dor:assemblyWF:jp2-create']
    end
  end
end