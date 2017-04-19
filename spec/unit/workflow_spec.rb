require 'spec_helper'

class WorkflowTest < RobotMaster::Workflow
  # expose protected methods
  def qualify(step)
    super(step)
  end

  def parse_process_node(node)
    super(node)
  end
end

describe RobotMaster::Workflow do
  before(:each) do
    Resque.redis = MockRedis.new
    Resque.mock!
  end

  subject {
    WorkflowTest.new('dor', 'accessionWF', File.read('spec/fixtures/accessionWF.xml'))
  }

  it 'expected public methods' do
    %w(perform qualify).map(&:to_sym).each do |proc|
      expect(subject.respond_to?(proc)).to be_truthy
    end
  end

  it 'initialization errors' do
    expect {
      WorkflowTest.new('dor', 'willNotFindWF')
    }.to raise_error(Errno::ENOENT)
  end

  context '#qualify' do
    it 'simple' do
      expect(subject.qualify('foo-bar')).to eq 'dor:accessionWF:foo-bar'
    end
  end

  context '#qualified?' do
    it 'yes' do
      expect(described_class.qualified?('dor:accessionWF:foo-bar')).to be_truthy
    end

    it 'no' do
      expect(described_class.qualified?('a')).to be_falsey
      expect(described_class.qualified?('a:b')).to be_falsey
      expect(described_class.qualified?('a:b-c')).to be_falsey
      expect(described_class.qualified?('a:b:c:d')).to be_falsey
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
      expect(step[:skip]).to be_falsey
    end

    it 'waiting' do
      doc = Nokogiri::XML('<process name="initiate" status="waiting"/>')
      expect(subject.parse_process_node(doc.root)[:skip]).to be_falsey
    end

    it 'completed' do
      doc = Nokogiri::XML('<process name="initiate" status="completed"/>')
      expect(subject.parse_process_node(doc.root)[:skip]).to be_truthy
    end

    it 'skip-queue' do
      doc = Nokogiri::XML('<process name="initiate" skip-queue="true"/>')
      expect(subject.parse_process_node(doc.root)[:skip]).to be_truthy
    end

    it 'skip-queue false' do
      doc = Nokogiri::XML('<process name="initiate" skip-queue="false"/>')
      expect(subject.parse_process_node(doc.root)[:skip]).to be_falsey
    end

    context 'single prereq' do
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

    context 'malformed prereq' do
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

  context '#self.perform without lanes' do
    before(:each) do
      allow(Dor::Config.workflow.client).to receive(:get_lane_ids).and_return([
        'AAA'
      ])
      allow(Dor::Config.workflow.client).to receive(:get_objects_for_workstep).and_return([
        'druid:aa111bb2222',
        'druid:py156ps0477',
        'druid:tt628cb6479',
        'druid:ct021wp7863'
      ])
    end

    context 'dor:assemblyWF' do
      let(:queues) {
        %w(
          dor_assemblyWF_accessioning-initiate_AAA
          dor_assemblyWF_checksum-compute_AAA
          dor_assemblyWF_exif-collect_AAA
          dor_assemblyWF_jp2-create_AAA
        )
      }

      it 'should perform' do
        wf = WorkflowTest.new('dor', 'assemblyWF', File.read('spec/fixtures/assemblyWF.xml'))
        wf.perform
        # ap({:queues => Resque.queues})
        expect(Resque.queues.sort).to eq(queues)
        {
          'accessioning-initiate' => 'AccessioningInitiate',
          'exif-collect' => 'ExifCollect',
          'checksum-compute' => 'ChecksumCompute',
          'jp2-create' => 'Jp2Create'
        }.each do |k, v|
          q = %(dor_assemblyWF_#{k}_AAA)
          expect(Resque.size(q)).to eq 4
          %w(
            druid:aa111bb2222
            druid:py156ps0477
            druid:tt628cb6479
            druid:ct021wp7863
          ).each do |druid|
            expect(Resque.pop(q)).to eq('class' => %(Robots::DorRepo::Assembly::#{v}),
                                        'args' => [druid])
          end
          expect(Resque.size(q)).to eq 0
        end
      end
    end
  end

  context '#self.perform with exception' do
    before(:each) do
      expect(Dor::Config.workflow.client).to receive(:get_lane_ids).and_raise(NotImplementedError)
    end

    context 'dor:assemblyWF' do
      it 'should perform' do
        expect {
          described_class.perform('dor', 'assemblyWF')
        }.to raise_error(NotImplementedError)
        expect(Resque.queues).to eq([])
      end
    end
  end

  context '#self.perform with no prereq' do
    it 'should run empty prereq' do
      xml = File.read('spec/fixtures/singleStepWF.xml')
      wf = RobotMaster::Workflow.new('dor', 'singleStepWF', xml)
      allow(Dor::Config.workflow.client).to receive(:get_lane_ids).and_return([
        'default'
      ])
      allow(Dor::Config.workflow.client).to receive(:get_objects_for_workstep).and_return([
        'druid:aa111bb2222'
      ])
      wf.perform
      expect(Resque.queues).to eq(['dor_singleStepWF_doit_default'])
    end
  end

  context '#initialize with XML' do
    it 'should initialize' do
      xml = File.read('spec/fixtures/singleStepWF.xml')
      wf = RobotMaster::Workflow.new('dor', 'singleStepWF', xml)
      expect(wf.class).to eq RobotMaster::Workflow
      expect(wf.repository).to eq 'dor'
      expect(wf.workflow).to eq 'singleStepWF'
    end
  end

  context '#limit' do
    it 'should pass limit flag from workflow xml' do
      xml = File.read('spec/fixtures/singleStepWF.xml')
      wf = RobotMaster::Workflow.new('dor', 'singleStepWF', xml)
      allow(wf).to receive(:perform_on_process).with({
                                                       name: 'dor:singleStepWF:doit',
                                                       prereq: [],
                                                       skip: false,
                                                       limit: 1
                                                     }) { 0 } # don't actually run perform on process
      wf.perform
    end
    it 'should use default limit from workflow xml' do
      xml = '<workflow-def id="singleStepWF" repository="dor">
  <process name="doit" sequence="1"/>
</workflow-def>'
      wf = RobotMaster::Workflow.new('dor', 'singleStepWF', xml)
      allow(wf).to receive(:perform_on_process).with({
                                                       name: 'dor:singleStepWF:doit',
                                                       prereq: [],
                                                       skip: false,
                                                       limit: nil
                                                     }) { 0 } # don't actually run perform on process
      wf.perform
    end
  end
end
