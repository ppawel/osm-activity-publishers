require './config'
require './osc_parser'

require 'httparty'
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

  def generate_activities(changeset_id, changeset_tstamp, user_id, user_name)
    # Prepare JSON based on the template.
    title = "#{user_name} added changeset #{changeset_id}"
    content = get_description_from_changemonger(changeset_id)
    geom = get_changeset_geom(changeset_id)

    json = eval_file('changeset_activity.json', binding)
    puts json

    # Send it to the server.
    response = self.class.post('/activities', {:body => {:json => json}})
    puts response.inspect
  end

  def get_changeset(changeset_id)
    sql = eval_file('get_changeset.sql', binding)
    @conn.query(sql).collect {|row| Hash[row]}
  end

  def get_changeset_geom(changeset_id)
    sql = eval_file('get_changeset.sql', binding)
    sql = "SELECT ST_Union(changeset_members.geom) FROM (#{sql}) AS changeset_members"
    @conn.query(sql).getvalue(0, 0)
  end

  protected

  def eval_file(file_name, b)
    eval('"' + File.open(file_name, 'rb').read.gsub('"', '\"') + '"', b)
  end

  def get_description_from_changemonger(changeset_id)
    IO.popen("./run_changemonger.sh #{changeset_id}") {|f| f.read}
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

# Main part of this script...

if ARGV.size != 1
  puts 'Usage: process_osc.rb <file_name>'
  exit
end

processor = ChangesetProcessor.new

parse_osc(ARGV[0]) do |changeset_id, xml|
  puts "Processing changeset #{changeset_id}..."

  dump_xml_to_tmp_file(changeset_id, xml)
  processor.generate_activities(changeset_id, get_from_xml(xml, 'timestamp'), get_from_xml(xml, 'uid'),
    get_from_xml(xml, 'user'))
  remove_tmp_file(changeset_id)
end
