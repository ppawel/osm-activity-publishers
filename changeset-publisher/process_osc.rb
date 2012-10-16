require './config'
require './osc_parser'

require 'httparty'
require 'open-uri'
require 'pg'

class ChangesetProcessor
  include HTTParty

  base_uri $config['activity_server_url']

  attr_accessor :conn

  def initialize
    @conn = PGconn.open(
      :host => $config['postgis_db_host'],
      :port => $config['postgis_db_port'],
      :dbname => $config['postgis_db_dbname'],
      :user => $config['postgis_db_user'],
      :password => $config['postgis_db_password'])
  end

  def generate_activities(changeset_id, changeset_tstamp, user_id, user_name, xml)
    geom = get_geom_from_xml(xml[:create], xml[:modify], xml[:delete])

    if geom.nil?
      puts " No geometry for the changeset found in the database, ignoring"
      return
    end

    # Prepare JSON based on the template.
    title = "#{user_name} added changeset #{changeset_id}"
    content = get_description_from_changemonger(changeset_id)

    json = eval_file('changeset_activity.json', binding)
    #puts json

    # Send it to the server.
    response = self.class.post('/activities', {:body => {:json => json}})
    #puts response.inspect
  end

  protected

  def eval_file(file_name, b)
    eval('"' + File.open(file_name, 'rb').read.gsub('"', '\"') + '"', b)
  end

  def get_description_from_changemonger(changeset_id)
    open("http://localhost:5000/api/changeset/#{changeset_id}") {|io| io.read}
  end

  def get_node_geom(id)
    result = @conn.query("SELECT ST_Y(geom), ST_X(geom) FROM nodes WHERE id = #{id}")
    [result.getvalue(0, 0), result.getvalue(0, 1)] if result.ntuples > 0
  end

  def get_geom_geom(geom)
    result = @conn.query("SELECT ST_Y('#{geom}'::geometry), ST_X('#{geom}'::geometry)")
    [result.getvalue(0, 0), result.getvalue(0, 1)]
  end

  def get_way_geom(id)
    points = []
    result = @conn.query("SELECT ST_DumpPoints(linestring) AS points FROM ways WHERE id = #{id}")
    result.each do |row|
      row['points'].match(/\,(.*?)\)/) {|m| points << get_geom_geom(m[1])}
    end
    points
  end

  def points_to_wkt(points)
    s = points.reduce('') {|total, p| total + "#{p[0]} #{p[1]},"}[0..-2]
    "MULTIPOINT(#{s})"
  end

  def get_geom_from_xml(create_xml, modify_xml, delete_xml)
    points = []
    # Geometry for new and deleted nodes is in the XML - no need for database lookup.
    create_xml.scan(/<node.*?lat="(.*?)" lon="(.*?)"/).each {|m| points << [m[1].to_f, m[0].to_f]}
    delete_xml.scan(/<node.*?lat="(.*?)" lon="(.*?)"/).each {|m| points << [m[1].to_f, m[0].to_f]}

    # For modified nodes let's take both old and new coordinates.
    modify_xml.scan('<node.*?id="(.*?).*?lat="(.*?)" lon="(.*?)""').each do |m|
      points << get_node_geom(m[0].to_i)
      points << [m[2].to_f, m[1].to_f]
    end

    (create_xml + modify_xml + delete_xml).scan(/<way.*?id="(.*?)"/m).each do |m|
      points += get_way_geom(m[0].to_i)
    end

    if !points.empty?
      wkt = points_to_wkt(points.select {|p| p}.uniq)
      @conn.query("SELECT ST_SetSRID(ST_GeomFromText('#{wkt}'), 4326)").getvalue(0, 0)
    end
  end
end

def dump_xml_to_tmp_file(changeset_id, xml)
  tmp_file_name = "/tmp/_#{changeset_id}.osc"
  f = File.open(tmp_file_name, 'wb')
  f.write(xml)
  f.close
end

def remove_tmp_file(changeset_id)
  tmp_file_name = "/tmp/_#{changeset_id}.osc"
  File.delete(tmp_file_name)
end

# Hacky!
def get_from_xml(xml, field_name)
  m = xml.match("#{field_name}\=\"(.*?)\"")
  $1
end

def log_time(name)
  before = Time.now
  if block_given?
    yield
  end
  end_time = Time.now
  puts "#{name} took #{Time.now - before}"
end

# Main part of this script...

if ARGV.size != 1
  puts 'Usage: process_osc.rb <file_name>'
  exit
end

puts "Processing file #{ARGV[0]}..."

processor = ChangesetProcessor.new

parse_osc(ARGV[0]) do |changeset_id, xml, create_xml, modify_xml, delete_xml|
  puts "Processing changeset #{changeset_id} (xml size = #{xml.size})..."

  if xml.size > $config['xml_size_limit']
    puts " Changeset too large, ignoring"
    next
  end

  dump_xml_to_tmp_file(changeset_id, xml)

  log_time ' generate_activities' do processor.generate_activities(changeset_id, get_from_xml(xml, 'timestamp'), get_from_xml(xml, 'uid'),
    get_from_xml(xml, 'user'), {:create => create_xml, :modify => modify_xml, :delete => delete_xml}) end

  remove_tmp_file(changeset_id)
end
