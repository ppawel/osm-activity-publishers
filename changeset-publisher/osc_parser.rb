require 'xml'

def parse_osc(file_name)
  changesets = {}
  reader = XML::Reader.file(file_name)

  while reader.read do
    if ['create', 'modify', 'delete'].include?(reader.name)
      current_action = reader.name
      next
    end

    next if !['node', 'way', 'relation'].include?(reader.name) or reader.node_type != 1

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
    create_xml = ''
    modify_xml = ''
    delete_xml = ''
    actions['create'].each {|action| create_xml += "  <create>\n    #{action}\n  </create>\n"}
    actions['modify'].each {|action| modify_xml += "  <modify>\n    #{action}\n  </modify>\n"}
    actions['delete'].each {|action| delete_xml += "  <delete>\n    #{action}\n  </delete>\n"}
    xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><osmChange>#{create_xml}#{modify_xml}#{delete_xml}</osmChange>"
    yield changeset_id, xml, create_xml, modify_xml, delete_xml
  end
end
