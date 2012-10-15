Changeset Activity Publisher
============================

This publisher interfaces with the OpenStreetMap Activity Server and publishes changeset activities. It is integrated
with Changemonger in order to produce user-friendly changeset descriptions.

Requirements
============

* Activity Server instance up and running
* OSM database in PostGIS (snapshot) schema (temporary requirement, may change in the future!)

Configuration
=============

The `config.rb` file must be used to configure database connection parameters and the URL to the activity server instance.

Usage
=====

The `process_osc.sh` script can be used to process a file in the standard OsmChange format. The publisher goes through the file changeset by changeset and produces activities. The activity JSON document is then sent to the activity server.

The script can be executed as follows:

`process_osc.sh <file_name>`
