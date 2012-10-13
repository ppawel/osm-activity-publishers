#!/bin/bash

cd changemonger
python2 ./app.py &> ../changemonger.log &

CHANGEMONGER_PID=$!

sleep 1

cd ..
ruby process_osc.rb $1

PUBLISHER_STATUS=$?

echo "Killing Changemonger and exiting..."

kill $CHANGEMONGER_PID
exit $PUBLISHER_STATUS
