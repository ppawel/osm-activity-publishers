require './config'

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

  def generate_activities(changeset_data)
    # Prepare JSON based on the template.
    count_nodes = changeset_data.select {|row| row['element_type'] == 'N'}.size
    count_ways = changeset_data.select {|row| row['element_type'] == 'W'}.size
    count_relations = changeset_data.select {|row| row['element_type'] == 'R'}.size

    changeset_id = changeset_data[0]['changeset_id']
    changeset_tstamp = changeset_data[0]['tstamp']
    user_id = changeset_data[0]['user_id']
    user_name = changeset_data[0]['user_name']
    title = "#{user_name} added changeset #{changeset_id}"
    content = "nodes: #{count_nodes}, ways: #{count_ways}, relations: #{count_relations}"
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
end

# Main part of this script...

if ARGV.size != 1
  puts 'Usage: process_osc.rb <file_name>'
  exit
end

#processor = ChangesetProcessor.new
#changeset_data =  processor.get_changeset(changeset_id)
#processor.generate_activities(changeset_data)