require 'xml'

if ARGV.size != 2
  puts 'Usage: extract_changesets.rb <osc file> <output dir>'
  exit
end

puts 'Looking for changesets...'

changeset_ids = []

for line in open(ARGV[0]) {|f| f.grep(/changeset="(\d+)"/)}
  line.match(/changeset="(\d+)"/) {|m| changeset_ids << m[1].to_i}
end

changeset_ids.uniq!.sort

puts "Got #{changeset_ids.size} changeset(s) to process..."

parser = XML::Parser.file(ARGV[0])
osc_doc = parser.parse

puts 'Parsed the XML file...'

changeset_ids.each_with_index do |changeset_id, index|
  doc = XML::Document.new()
  doc.root = XML::Node.new('osmChange')

  for action in ['create', 'modify', 'delete']
    action_node = XML::Node.new(action)
    doc.root << action_node
    nodes = osc_doc.find("/osmChange/#{action}/*[@changeset=\"#{changeset_id}\"]", 't:http://osc/')
    nodes.to_a.each {|node| action_node << doc.import(node)}
  end

  file_name = "#{ARGV[1]}/#{changeset_id}.osc"
  doc.save(file_name, :indent => true, :encoding => XML::Encoding::UTF_8)
  puts "Saved #{file_name} (#{index + 1} of #{changeset_ids.size})"
end
