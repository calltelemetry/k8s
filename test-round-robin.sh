#!/bin/bash

# Number of requests to make
NUM_REQUESTS=20

echo "Testing round-robin load balancing with $NUM_REQUESTS requests..."
echo

# Array to store pod IPs for each request
declare -a request_ips

for i in $(seq 1 $NUM_REQUESTS); do
    echo "Request $i:"

    # Make the request and extract the pod IP
    response=$(curl -s -H "Host: dev.calltelemetry.com" http://192.168.123.237/echo)
    pod_ip=$(echo $response | grep -o '"ip":"[^"]*"' | cut -d'"' -f4)

    echo "  Pod IP: $pod_ip"

    # Store the IP
    request_ips[$i]="$pod_ip"

    echo

    # Add a small delay between requests
    sleep 1
done

echo "Summary:"
echo "--------"
echo "Request IPs:"
for i in $(seq 1 $NUM_REQUESTS); do
    echo "  Request $i: ${request_ips[$i]}"
done

echo
echo "Unique IPs found:"
echo "${request_ips[@]}" | tr ' ' '\n' | sort | uniq -c | sort -nr
