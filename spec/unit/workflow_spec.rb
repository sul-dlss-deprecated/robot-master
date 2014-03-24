require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require File.expand_path(File.dirname(__FILE__) + '/../../config/boot')

class WorkflowTest < RobotMaster::Workflow
  # expose protected methods
  def qualify(step); super(step); end
  def qualified?(step); super(step); end
  def parse_qualified(step); super(step); end
  def parse_process_node(node); super(node); end
end

describe RobotMaster::Workflow do
  subject(:master) {
    WorkflowTest.new('dor', 'accessionWF')
  }
  
  it 'initialization errors' do
    expect {
      WorkflowTest.new('dor', 'willNotFindWF')
    }.to raise_error(Exception)
  end

  context '#qualify' do
    it "simple" do
      expect(master.qualify('foo-bar')).to eq 'dor:accessionWF:foo-bar'
    end
  end

  context '#qualified?' do
    it "yes" do
      expect(master.qualified?('dor:accessionWF:foo-bar')).to be true
    end
  
    it "no" do
      expect(master.qualified?('a')).to be false
      expect(master.qualified?('a:b')).to be false
      expect(master.qualified?('a:b:c:d')).to be false
    end
  end

  context '#parse_qualified' do
    it 'does something' do
      expect(master.parse_qualified('dor:assemblyWF:jp2-create')).to eq ['dor', 'assemblyWF', 'jp2-create']
    
    end
  end

  context '#queue_name' do
    let(:priorities) {  
      %w{critical high default low}.map(&:to_sym)
    }
  
    it 'handles priority symbols' do
      priorities.each do |priority|
        expect(master.queue_name('foo-bar', priority)).to eq "dor_accessionWF_foo-bar_#{priority}"
      end
    end
  
    it 'handles default' do
      expect(master.queue_name('foo-bar')).to eq 'dor_accessionWF_foo-bar_default'      
    end
  
    it 'handles priority numbers' do
      expect(master.queue_name('foo-bar', 0)).to eq 'dor_accessionWF_foo-bar_default'
      expect(master.queue_name('foo-bar', 1)).to eq 'dor_accessionWF_foo-bar_high'      
    end
  
    it 'handles qualified names' do
      expect(master.queue_name('dor:someWF:foo-bar')).to eq 'dor_someWF_foo-bar_default'      
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
  
    context 'with qualified name' do
      let(:doc) {
        Nokogiri::XML('
       <process name="foo-bar">
         <prereq>dor:assemblyWF:jp2-create</prereq>
        </process>'
        )
      }
      it 'should' do
        expect(master.parse_process_node(doc.root)[:name]).to eq 'dor:accessionWF:foo-bar'
        expect(master.parse_process_node(doc.root)[:prereq]).to eq ['dor:assemblyWF:jp2-create']
      end
    end
  
    context "malformed prereq" do
      let(:doc) {
        Nokogiri::XML('
         <process name="remediate-object">
           <Prereq>content-metadata</Prereq>
          </process>'
        )
      }
      it 'should' do
        expect(master.parse_process_node(doc.root)[:prereq]).to eq []
      end
    end
  end
end