require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require File.expand_path(File.dirname(__FILE__) + '/../../config/boot')

class WorkflowTest < RobotMaster::Workflow
  # expose protected methods
  def qualify(step); super(step); end
  def parse_process_node(node); super(node); end
end

describe RobotMaster::Workflow do
  subject {
    WorkflowTest.new('dor', 'accessionWF')
  }
  
  it 'expected public methods' do
    %w{perform qualify}.map(&:to_sym).each do |proc|
      expect(subject.respond_to?(proc)).to be_true
    end
  end
  
  it 'initialization errors' do
    expect {
      WorkflowTest.new('dor', 'willNotFindWF')
    }.to raise_error(Exception)
  end

  context '#qualify' do
    it "simple" do
      expect(subject.qualify('foo-bar')).to eq 'dor:accessionWF:foo-bar'
    end
  end

  context '#qualified?' do
    it "yes" do
      expect(described_class.qualified?('dor:accessionWF:foo-bar')).to be true
    end
  
    it "no" do
      expect(described_class.qualified?('a')).to be false
      expect(described_class.qualified?('a:b')).to be false
      expect(described_class.qualified?('a:b-c')).to be false
      expect(described_class.qualified?('a:b:c:d')).to be false
    end
  end
  
  context '#parse_qualified' do
    it 'fails' do
      expect { 
        described_class.parse_qualified('jp2-create') 
      }.to raise_error(ArgumentError)
    end
  
    it 'does something' do
      expect(described_class.parse_qualified('dor:assemblyWF:jp2-create')).to eq ['dor', 'assemblyWF', 'jp2-create']
  
    end
  end

  context '#parse_process_node' do
    it 'empty' do
      doc = Nokogiri::XML('<process name="initiate"/>')
      step = subject.parse_process_node(doc.root)
      expect(step[:name]).to eq 'dor:accessionWF:initiate'
      expect(step[:skip]).to be false
    end

    it 'waiting' do
      doc = Nokogiri::XML('<process name="initiate" status="waiting"/>')
      expect(subject.parse_process_node(doc.root)[:skip]).to be false
    end

    it 'completed' do
      doc = Nokogiri::XML('<process name="initiate" status="completed"/>')
      expect(subject.parse_process_node(doc.root)[:skip]).to be true
    end

    it 'skip-queue' do
      doc = Nokogiri::XML('<process name="initiate" skip-queue="true"/>')
      expect(subject.parse_process_node(doc.root)[:skip]).to be true
    end

    it 'skip-queue false' do
      doc = Nokogiri::XML('<process name="initiate" skip-queue="false"/>')
      expect(subject.parse_process_node(doc.root)[:skip]).to be false
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
        expect(subject.parse_process_node(doc.root)[:prereq]).to eq [
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
        expect(subject.parse_process_node(doc.root)[:prereq]).to eq [
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
        step = subject.parse_process_node(doc.root)
        expect(step[:name]).to eq 'dor:accessionWF:foo-bar'
        expect(step[:prereq]).to eq ['dor:assemblyWF:jp2-create']
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
        expect(subject.parse_process_node(doc.root)[:prereq]).to eq []
      end
    end
  end
  
  context '#self.perform' do
    let(:queues) { [
        "dor_assemblyWF_accessioning-initiate_low",
        "dor_assemblyWF_accessioning-initiate_default",
        "dor_assemblyWF_accessioning-initiate_high",
        "dor_assemblyWF_accessioning-initiate_critical",
        "dor_assemblyWF_exif-collect_low",
        "dor_assemblyWF_exif-collect_default",
        "dor_assemblyWF_exif-collect_high",
        "dor_assemblyWF_exif-collect_critical",
        "dor_assemblyWF_checksum-compute_low",
        "dor_assemblyWF_checksum-compute_default",
        "dor_assemblyWF_checksum-compute_high",
        "dor_assemblyWF_checksum-compute_critical",
        "dor_assemblyWF_jp2-create_low",
        "dor_assemblyWF_jp2-create_default",
        "dor_assemblyWF_jp2-create_high",
        "dor_assemblyWF_jp2-create_critical"
      ] }
    before(:each) do
      Dor::WorkflowService.stub(:get_objects_for_workstep).and_return({
        "druid:aa111bb2222" => 1000,
        "druid:py156ps0477" => 100,
        "druid:tt628cb6479" => 0,
        "druid:ct021wp7863" => -100
      })
      Resque.redis = MockRedis.new
    end
    
    it 'dor:assemblyWF' do
      described_class.perform('dor', 'assemblyWF')
      expect(Resque.queues).to eq(queues)
      expect(Resque.peek('dor_assemblyWF_jp2-create_critical')).to eq({
        'class' => 'Robots::Dor::Assembly::Jp2Create',
        'args' => [ 'druid:aa111bb2222' ]
      })
      expect(Resque.peek('dor_assemblyWF_jp2-create_high')).to eq({
        'class' => 'Robots::Dor::Assembly::Jp2Create',
        'args' => [ 'druid:py156ps0477' ]
      })
      expect(Resque.peek('dor_assemblyWF_jp2-create_default')).to eq({
        'class' => 'Robots::Dor::Assembly::Jp2Create',
        'args' => [ 'druid:tt628cb6479' ]
      })
      expect(Resque.peek('dor_assemblyWF_jp2-create_low')).to eq({
        'class' => 'Robots::Dor::Assembly::Jp2Create',
        'args' => [ 'druid:ct021wp7863' ]
      })
    end
  end
end