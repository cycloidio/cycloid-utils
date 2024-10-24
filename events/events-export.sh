#!/bin/bash


help() {
        echo "Usage: $0 <organization> <timestart> <timeend|now> [json|csv]"
        echo "  export variable such CY_API_KEY and CY_API_URL"
        echo "  default output [json]"
        echo ""
        echo "Example:"
        echo "  export CY_API_URL=https://api.foo.com"
        echo "  export CY_API_KEY=xxxxxxxxxxxx"
        echo "  $0 cycloid 2024-10-20 2024-10-24"
        echo "  $0 cycloid 2024-10-20 now"
        echo "  $0 cycloid 2024-10-20 now csv"
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

convert_to_timestamp() {
  # provide extra 000 for second
  echo $(date -d "$1 23:59:59" +"%s000")
}

EVENT_TIMESTAMP_START=$(convert_to_timestamp $EVENT_TIME_START)
EVENT_TIMESTAMP_END=$(convert_to_timestamp $EVENT_TIME_END)

get_events() {
  curl -q "$CY_API_URL/organizations/$CY_ORG/events?begin=$EVENT_TIMESTAMP_START&end=$EVENT_TIMESTAMP_END" 2>/dev/null \
    -H "authorization: Bearer $CY_API_KEY" \
    -H 'content-type: application/vnd.cycloid.io.v1+json' \
    --compressed | jq .data[]
}





# main

events=$(get_events)

if [ "$OUTPUT_FORMAT" = "csv" ]; then
  echo "id,time,title,severity,message,tags"
  echo $events | jq -r '. | "\(.id),\(.timestamp / 1000 | todate),\(.title),\(.severity),\(.message),\([.tags[] | .key + "=" + .value] | join(" "))"'
else
  echo $events | jq .
fi
