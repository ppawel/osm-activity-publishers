#!/bin/bash

cd data

if [ ! -f current.osc ]; then
  echo "No current.osc file found, downloading new one..."
  osmosis --read-replication-interval --write-xml-change current.osc
fi

echo "Publishing activities from current.osc..."

cd ../..
./process_osc.sh replication/data/current.osc 2> publisher.log

STATUS=$?

echo "Done (status = $STATUS)"

if [ "$STATUS" != "0" ]; then
  echo "Failed publish activities... bye!"
  exit 1
fi

cd replication
osmosis --read-xml-change data/current.osc --write-pgsql-change authFile=authFile

if [ "$?" != "0" ]; then
  echo "Failed to apply current.osc to the database!"
  exit 1
fi

echo "current.osc applied to the database so removing it"

rm data/current.osc
