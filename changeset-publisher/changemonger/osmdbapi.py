##  Changemonger: An OpenStreetMap change analyzer
##  Copyright (C) 2012 Serge Wroclawski
##
##  This program is free software: you can redistribute it and/or modify
##  it under the terms of the GNU Affero General Public License as
##  published by the Free Software Foundation, either version 3 of the
##  License, or (at your option) any later version.
##
##  This program is distributed in the hope that it will be useful,
##  but WITHOUT ANY WARRANTY; without even the implied warranty of
##  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##  GNU Affero General Public License for more details.
##
##  You should have received a copy of the GNU Affero General Public License
##  along with this program.  If not, see <http://www.gnu.org/licenses/>.

"""Provides a simple abstraction against the OSM API"""
"""Operations are implemented using PostGIS snapshot schema database instead of public API calls"""

import psycopg2
import psycopg2.extensions
import psycopg2.extras

from config import __CONFIG

import logging

logging.basicConfig(level=logging.DEBUG, format='%(asctime)-15s %(message)s')

try:
    dbconn = psycopg2.connect(__CONFIG["connection_string"])
except:
    raise Exception("Unable to connect to the database")

dbcursor = dbconn.cursor(cursor_factory = psycopg2.extras.DictCursor)
# This will enable automatic hstore column -> dict conversion which is nice for columns with tags.
psycopg2.extras.register_hstore(dbcursor, unicode = True)
# Fix some unicode madness...
psycopg2.extensions.register_type(psycopg2.extensions.UNICODE)
psycopg2.extensions.register_type(psycopg2.extensions.UNICODEARRAY)

def getNode(id, version = None):
    id = str(id)
    logging.debug("Retrieving node %s version %s" % (id, version))
    dbcursor.execute("SELECT * FROM nodes WHERE id = %s" % id)
    row = dbcursor.fetchone()
    logging.debug("getNode(%d): %s" % (int(id), str(rows)))
    return createNodeXml(row)

def getWay(id, version = None):
    id = str(id)
    logging.debug("Retrieving way %s version %s" % (id, version))
    dbcursor.execute("SELECT * FROM ways w INNER JOIN way_nodes wn ON (wn.way_id = w.id) WHERE w.id = %s" % id)
    rows = dbcursor.fetchall()
    logging.debug("getWay(%d): %s" % (int(id), str(rows)))
    return createWayXml(rows)

def getRelation(id, version = None):
    id = str(id)
    logging.debug("Retrieving relation %s version %s" % (id, version))
    dbcursor.execute("SELECT * FROM relations r INNER JOIN relation_members rm ON (rm.relation_id = r.id) WHERE r.id = %s" % id)
    rows = dbcursor.fetchall()
    logging.debug("getRelation(%d): %s" % (int(id), str(rows)))
    return createRelationXml(rows)

def getChangeset(id):
    logging.debug("getChangeset(%d)" % int(id))
    return createChangesetXml(id)

def getChange(id):
    logging.debug("getChange(%d)" % int(id))
    return open("/tmp/_" + str(id) + ".osc").read()

def getWaysforNode(id):
    id = str(id)
    logging.debug("Retrieving node %s ways" % id)
    dbcursor.execute("SELECT * FROM ways w INNER JOIN way_nodes wn ON (wn.way_id = w.id) WHERE wn.node_id = %s ORDER BY w.id" % id)
    rows = dbcursor.fetchall()
    logging.debug("getWaysforNode(%d): %s" % (int(id), str(rows)))
    return createWayXml(rows)

def getRelationsforElement(type, id):
    id = str(id)
    logging.debug("Retrieving relations for %s %s" % (type, str(id)))
    dbcursor.execute("SELECT * FROM relations r INNER JOIN relation_members rm ON (rm.relation_id = r.id) WHERE rm.member_id = %s ORDER BY rm.relation_id, rm.member_type, rm.member_id" % id)
    rows = dbcursor.fetchall()
    logging.debug("getRelationsforElement(%d): %s" % (int(id), str(rows)))
    return createRelationsXml(rows)

## Caution: XML handling! Not pretty!

from xml.dom.minidom import getDOMImplementation

domimpl = getDOMImplementation()

def createOsmDocument():
    return domimpl.createDocument(None, "osm", None)

def createNodeXml(node_row):
    newdoc = createOsmDocument()
    node_el = newdoc.createElement('node')
    node_el.setAttribute('id', str(node_row['id']))
    node_el.setAttribute('version', str(node_row['version']))

    for k, v in node_row['tags'].items():
        tag_el = newdoc.createElement('tag')
        tag_el.setAttribute('k', k)
        tag_el.setAttribute('v', v)
        node_el.appendChild(tag_el)

    newdoc.documentElement.appendChild(node_el)
    return newdoc.toprettyxml(encoding = 'utf-8')

def createWayXml(way_rows):
    newdoc = createOsmDocument()
    appendWayXml(newdoc, newdoc.documentElement, way_rows)
    return newdoc.toprettyxml(encoding = 'utf-8')

def createNodeWaysXml(way_rows):
    newdoc = createOsmDocument()
    appendWayXml(newdoc, newdoc.documentElement, way_rows)
    return newdoc.toprettyxml(encoding = 'utf-8')

def createRelationsXml(all_relations_rows):
    newdoc = createOsmDocument()

    if len(all_relations_rows) == 0:
      return newdoc.toprettyxml(encoding = 'utf-8')

    id = -1#relation_rows[0]['relation_id']
    relation_rows = []

    for row in all_relations_rows:
      if id != row['relation_id'] and id != -1:
        appendRelationXml(newdoc, newdoc.documentElement, relation_rows)
        relation_rows = []

      id = row['relation_id']
      relation_rows.append(row)

    logging.debug(all_relations_rows)#newdoc.toprettyxml(encoding = 'utf-8')

    return newdoc.toprettyxml(encoding = 'utf-8')

def createChangesetXml(id):
    newdoc = createOsmDocument()
    changeset_el = newdoc.createElement('changeset')
    changeset_el.setAttribute('id', str(id))
    changeset_el.setAttribute('uid', str(1234))
    changeset_el.setAttribute('user', str('abc'))
    newdoc.documentElement.appendChild(changeset_el)
    return newdoc.toprettyxml(encoding = 'utf-8')

def appendWayXml(doc, el, way_rows):
    if len(way_rows) == 0:
      return

    way_el = doc.createElement('way')
    way_el.setAttribute('id', str(way_rows[0]['id']))
    way_el.setAttribute('version', str(way_rows[0]['version']))

    for node in way_rows:
        node_el = doc.createElement('nd')
        node_el.setAttribute('ref', str(node['id']))
        way_el.appendChild(node_el)

    for k, v in way_rows[0]['tags'].items():
        tag_el = doc.createElement('tag')
        tag_el.setAttribute('k', k)
        tag_el.setAttribute('v', v)
        way_el.appendChild(tag_el)

    el.appendChild(way_el)

def appendRelationXml(doc, el, relation_rows):
    if len(relation_rows) == 0:
      return

    relation_el = doc.createElement('relation')
    relation_el.setAttribute('id', str(relation_rows[0]['id']))
    relation_el.setAttribute('version', str(relation_rows[0]['version']))

    el.appendChild(relation_el)
