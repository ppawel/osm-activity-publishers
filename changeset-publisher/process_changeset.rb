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
    changeset_id = changeset_data[0]['changeset_id']
    user_id = changeset_data[0]['user_id']
    title = "Changeset #{changeset_id}"
    content = "Changeset #{changeset_id}"
    json = eval('"' + File.open('changeset_activity.json', 'rb').read.gsub('"', '\"') + '"')

    # Send it to the server.
    response = self.class.post('/activities', {:body => {:json => json}})
    puts response.inspect
  end

  def get_changeset(id)
    sql = "
SELECT
  'N' AS element_type,
  changeset_id,
  user_id,
  tstamp,
  tags,
  geom
FROM nodes
WHERE changeset_id = #{id}

UNION

SELECT
  'R' AS element_type,
  changeset_id,
  user_id,
  tstamp,
  tags,
  NULL AS geom
FROM relations
WHERE changeset_id = #{id}

UNION

SELECT
  'W' AS element_type,
  changeset_id,
  user_id,
  tstamp,
  tags,
  linestring AS geom
FROM ways
WHERE changeset_id = #{id}
    "

    @conn.query(sql).collect {|row| Hash[row]}
  end
end

# Main part of this script...

if ARGV.size != 1
  puts 'Usage: process_changeset.rb <changeset_id>'
  exit
end

changeset_id = ARGV[0].to_i
processor = ChangesetProcessor.new
changeset_data =  processor.get_changeset(changeset_id)
processor.generate_activities(changeset_data)
