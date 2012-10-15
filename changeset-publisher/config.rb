$config = {
  'postgis_db_host' => 'localhost',
  'postgis_db_port' => 5432,
  'postgis_db_dbname' => 'osmdb',
  'postgis_db_user' => 'ppawel',
  'postgis_db_password' => 'aa',

  'activity_server_url' => 'http://localhost:3333/',

  # Ignore changesets above this limit (number of bytes in the XML document representing the changeset).
  'xml_size_limit' => 1000000
}
