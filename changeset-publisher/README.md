Changeset Activity Publisher
============================

This publisher interfaces with the OpenStreetMap Activity Server and publishes changeset activities.

Usage
=====

Processing a single changeset
-----------------------------

`process_changeset.rb` script can be used to fetch changeset data from the database by id and generate activity based on that data. The activity JSON document is then sent to the activity server.

The script can be executed as follows:

`process_changeset.rb <changeset_id>`

It will output the JSON document that is sent to the server and server's response.