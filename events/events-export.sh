#!/bin/bash

help() {
        echo "Usage: $0 <organization> <timestart> <timeend|now> [json|csv|csv-export]"
        echo "  export variable such CY_API_KEY and CY_API_URL"
        echo "  default output [json]"
        echo ""
        echo "Example:"
        echo "  export CY_API_URL=https://api.foo.com"
        echo "  export CY_API_KEY=xxxxxxxxxxxx"
        echo "  $0 cycloid 2024-10-20 2024-10-24"
        echo "  $0 cycloid 2024-10-20 now"
        echo "  $0 cycloid 2024-10-20 now csv"
        echo "  $0 cycloid \$(date -d yesterday +%Y-%m-%d) \$(date -d yesterday +%Y-%m-%d) csv-export"
}

if [ $# -lt 3 ]; then
    echo "error: You need to pass at least 3 arguments."
    help
    exit 0
fi

if [ -z "$CY_API_KEY" ]; then
    echo "error: CY_API_KEY is not defined. Please 'export CY_API_KEY=xxxxxxxxxxxx'"
    help
    exit 0
fi

# Default saas api
if [ -z "$CY_API_URL" ]; then
    CY_API_URL="https://http-api.cycloid.io"
fi

CY_ORG=$1
EVENT_TIME_START=$2
EVENT_TIME_END=$3
OUTPUT_FORMAT=$4

# Default json
if [ -z "$OUTPUT_FORMAT" ]; then
    OUTPUT_FORMAT="json"
fi

# If end now, check the current date
if [ "$EVENT_TIME_END" = "now" ]; then
  EVENT_TIME_END=$(date +%Y-%m-%d)
fi

# Convert date to timestamp. If hours is not provided, it will be set to 23:59:59
convert_to_timestamp() {
  hours=$2
  if [ -z "$hours" ]; then
    hours="23:59:59"
  fi
  # provide extra 000 for second (used with curl on the API)
  # echo $(date -d "$1 $hours" +"%s000")

  echo $(date -d "$1 $hours" +"%s")
}

# Retrieves events from the Cycloid API within the specified time range.
# Converts the provided start and end dates to timestamps and fetches
# the events occurring between these timestamps. The events are returned
# in JSON format and parsed using 'jq'.
get_events() {
  EVENT_TIMESTAMP_START=$(convert_to_timestamp $EVENT_TIME_START "00:00:00")
  EVENT_TIMESTAMP_END=$(convert_to_timestamp $EVENT_TIME_END "23:59:59")
  cy event list --begin $EVENT_TIMESTAMP_START --end $EVENT_TIMESTAMP_END -ojson 2>/dev/null| jq .[]

# same with curl
# curl -q "$CY_API_URL/organizations/$CY_ORG/events?begin=$EVENT_TIMESTAMP_START&end=$EVENT_TIMESTAMP_END" 2>/dev/null \
#   -H "authorization: Bearer $CY_API_KEY" \
#   -H 'content-type: application/vnd.cycloid.io.v1+json' \
#   --compressed | jq .data[]
}

# main

events=$(get_events)

if [ "$OUTPUT_FORMAT" = "csv" ] || [ "$OUTPUT_FORMAT" = "csv-export" ]; then
  STD_OUTPUT=/dev/stdout
  if [ "$OUTPUT_FORMAT" = "csv-export" ]; then
    STD_OUTPUT=/tmp/events.csv
    echo "Exporting $EVENT_TIME_START to $STD_OUTPUT"
  fi
  echo "id,time,title,severity,message,tags" > $STD_OUTPUT
  echo $events | jq -r '. | "\(.id),\(.timestamp / 1000 | todate),\(.title),\(.severity),\(.message),\([.tags[] | .key + "=" + .value] | join(" "))"' >> $STD_OUTPUT
else
  echo $events | jq .
fi
