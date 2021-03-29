#!/bin/bash

function show_help() {

	if [ -t 1 ]; then
	cat >&2 << EOF

SSLCheck - This script will check any domain for an existing SSL certificate and its expiry (for HTTPS)

How to use: sslcheck.sh valid/expire [Hostname]/[IP] [Port Number] [Certificate Domain] searchTimeout
This script requires OpenSSL to function - To check, run: openssl version

[Port Number] (Optional) - Default = 443
[Certificate Domain] is optional, default is hostname (Sometimes, a certificate can exist outside the domain name you provide)
searchTimeout (Optional) - Default = 5 seconds

Output:

* valid:	Checks to see if the site has an SSL Certificate

* expire:	Displays the number of remaining days for certificate validity (If negative, number of days since expiry)

EOF
	fi
}

# Check if OpenSSL is installed
for util in timeout openssl date; do
	type "$util" >/dev/null || error "OpenSSL is not found in \$PATH: $util"
done

# Error message function
function error() { 
	echo "Error! $*" >&2; exit 0; 
}

# Provide the result
function result() { 
	echo "$1"; exit 0; 
}

# Arguments
check_type="$1"
host="$2"
port="${3:-443}"
domain="${4:-$host}"
searchTimeout="${5:-5}"

# Input Validation
[ "$#" -lt 2 ] && show_help && exit 0
[ "$check_type" = "valid" ] || [ "$check_type" = "expire" ] || error "Wrong parameter - Use either 'valid' or 'expire'"
[[ "$port" =~ ^[0-9]+$ ]] || error "Port must be a number"
{ [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; } || error "Port number must be between 1 and 65535 (inclusive)"
[[ "$searchTimeout" =~ ^[0-9]+$ ]] || error "Search timeout must be a number"

# Grab Certificate
if ! output=$( echo \
| timeout "$searchTimeout" openssl s_client -servername "$domain" -verify_hostname "$domain" -connect "$host":"$port" 2>/dev/null )
then
	error "Failed to get certificate"
fi

# Run checks
if [ "$check_type" = "expire" ]; then
	expire_date=$( echo "$output" \
	| openssl x509 -noout -dates \
	| grep '^notAfter' | cut -d'=' -f2 )
	expire_date_epoch=$(date -d "$expire_date" +%s) || error "Failed to get expiration"
	current_date_epoch=$(date +%s)
	days_left=$(( (expire_date_epoch - current_date_epoch)/(3600*24) ))
	echo ""
	result "$days_left days remaining"

elif [ "$check_type" = "valid" ]; then
	verify_return_code=$( echo "$output" | grep -E '^ *Verify return code:' | sed -n 1p | sed 's/^ *//' | tr -s ' ' | cut -d' ' -f4 )
	echo ""
	if [ "$verify_return_code" -eq "0" ]; then result "Valid SSL Certificate Found!" ; else result "No Certificate Found" ; fi

fi
