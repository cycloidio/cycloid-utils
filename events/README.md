# events-export.sh

Scripts to used to export as json the events of an organzation from a specific time range

Usage:

```bash
export variable such CY_API_KEY and CY_API_URL

events-export.sh <organization> <timestart> <timeend|now> [json|csv|csv-export]
```

Example:

```bash
# Export CY_API_URL and CY_API_KEY
export CY_API_URL=https://api.foo.com
export CY_API_KEY=xxxxxxxxxxxx

# Get json report between 2024-10-20 2024-10-22
events-export.sh cycloid 2024-10-20 2024-10-22

# Get json report between 2024-10-20 and now
events-export.sh cycloid 2024-10-20 now

# Get json report between 2024-10-20 and now in CSV format
events-export.sh cycloid 2024-10-20 now csv

# Generate a daily CSV report for the previous day to /tmp/events.csv
events-export.sh cycloid $(date -d yesterday +%Y-%m-%d) $(date -d yesterday +%Y-%m-%d) csv-export
```