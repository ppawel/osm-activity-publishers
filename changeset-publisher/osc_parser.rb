require 'xml'

def parse_osc(file_name)
  changesets = {}
  reader = XML::Reader.file(ARGV[0])

  while reader.read do
    if ['create', 'modify', 'delete'].include?(reader.name)
      current_action = reader.name
      next
    end

    next if !['node', 'way', 'relation'].include?(reader.name)

    changeset_id = reader['changeset']
    next if !changeset_id

    if !changesets.has_key?(changeset_id)
      changesets[changeset_id] = {}
      changesets[changeset_id]['create'] = []
      changesets[changeset_id]['modify'] = []
      changesets[changeset_id]['delete'] = []
    end

    changesets[changeset_id][current_action] << reader.read_outer_xml
  end

  changesets.each do |changeset_id, actions|
    xml = '<?xml version="1.0" encoding="UTF-8"?><osmChange>'
    xml += "<create>#{actions['create'].join}</create>" if !actions['create'].empty?
    xml += "<modify>#{actions['modify'].join}</modify>" if !actions['modify'].empty?
    xml += "<delete>#{actions['delete'].join}</delete>" if !actions['delete'].empty?
    xml += '</osmChange>'
    yield changeset_id, xml
  end
end
