require 'awesome_print'
require 'nokogiri'
require 'restclient'

class RobotStatusBoard

  def count_ready wq_uri, step, prereq, lane
    uri = "#{wq_uri}?waiting=#{step}&completed=#{prereq}&lane-id=#{lane}&count-only=true"
    xml = RestClient.get uri
    doc = Nokogiri::XML(xml)
    doc.root['count'].to_i    
  end

  def count_status wq_uri, step, lane, type
    r, w, s = step.split(/:/)
    uri = "#{wq_uri}?repository=#{r}&workflow=#{w}&#{type}=#{s}&lane-id=#{lane}&count-only=true"
    xml = RestClient.get uri
    doc = Nokogiri::XML(xml)
    doc.root['count'].to_i
  end

  def map_workflow(wq_uri, repo, wf, flags = {})
    lane = flags[:lane]
    status = {}
    fn = "config/workflows/#{repo}/#{wf}.xml"
    doc = Nokogiri::XML(File.read(fn))
    doc.root.xpath('.//process').each do |p|
      step = p['name']
      fstep = [repo, wf, step].join(':')
      STDERR.puts "Processing step #{step}" if flags[:debug]
      status[step] = {}
      n = count_status(wq_uri, fstep, lane, 'waiting')
      status[step][:waiting] = n
      status[step][:ready] = n # assuming no prereqs
      p.xpath('prereq/text()').each do |pr| # XXX: assuming single prereq
        n = count_ready(wq_uri, fstep, [repo, wf, pr.to_s].join(':'), lane)
        status[step][:ready] = n
      end
      %w{error queued completed}.each do |s|
        status[step][s.to_sym] = count_status(wq_uri, fstep, lane, s)
      end
    end
    # ap({:status => status})
    status.each do |k, v|
      yield [repo, wf, "#{lane}", "#{k}", "#{v[:waiting]}", "#{v[:ready]}", "#{v[:error]}", "#{v[:queued]}", "#{v[:completed]}"]
    end
  end
  
end