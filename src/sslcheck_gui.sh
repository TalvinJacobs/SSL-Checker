#!/bin/bash

for util in timeout openssl date zenity; do
	type "$util" >/dev/null || error "$uril is not found in \$PATH"
done

# Intro Message
zenity --info --width=700 --height=250 --title="SSLChecker Information" --text="SSLCheck - This script will check any domain for an existing SSL certificate and its expiry (for HTTPS) \n \nHow to use: \n[Mandatory] valid/expire - Check certificate Validity/Check certificate expiration (days remaining)\n[Mandatory] Hostname/IP - Hostname or IP to check for SSL\n \n[Optional] Port Number - Between 1 and 65535 (Default = 443) \n[Optional] Certificate Domain - Specific location of SSL Certificate (Rarely different from original host. Default = Hostname/IP)\n[Optional] Search Timeout - Timeout in seconds (Default = 5)"

# Arguments
check_type=$(zenity --width=350 --height=100 --entry --title="Check Type (MAND)" --text="Enter Check Type (valid/expire): ")
host=$(zenity --width=350 --height=100 --entry --title="Hostname (MAND)" --text="Enter Hostname or IP:")
port=$(zenity --width=350 --height=100 --entry --title="Port (OPT)" --text="Enter Port Number [1-65535] (default = 443):")
[[ "$port" == "" ]] && port=443
domain=$(zenity --width=350 --height=100 --entry --title="Domain (OPT)" --text="Enter Domain (default = $host):")
[[ "$domain" == "" ]] && domain="$host"
searchTimeout=$(zenity --width=350 --height=100 --entry --title="Search Timeout (OPT)" --text="Enter Search Timeout (default = 5)")
[[ $searchTimeout == "" ]] && searchTimeout=5

function error {
	zenity --warning --width=350 --height=100 --text="$1"
}

function result {
	zenity --info --width=350 --height=100 --text="$1"
}

# Input Validation
[ "$check_type" = "valid" ] || [ "$check_type" = "expire" ] || error "Wrong parameters - Use either 'valid' or 'expire'"
[[ "$port" =~ ^[0-9]+$ ]] || error "Port must be a number!"
{ [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; } || error "Port number must be between 1 and 65535 (inclusive)"
[[ "$searchTimeout" =~ ^[0-9]+$ ]] || error "Search Timeout must be a number"

# Grab Certificate
if ! output=$( echo \
| timeout "$searchTimeout" openssl s_client -servername "$domain" -verify_hostname "$domain" -connect "$host":"$port" 2>/dev/null )
then
	error "Failed to get certificate"
fi

# Run checks
if [ "$check_type" = "expire" ]; then
	expire_date=$(echo "$output" \
		| openssl x509 -noout -dates \
		| grep '^notAfter' | cut -d'=' -f2
	)
	expire_date_epoch=$(date -d "$expire_date" +%s) || error "Failed to get expiration"
	current_date_epoch=$(date +%s)
	days_left=$(( (expire_date_epoch - current_date_epoch)/(3600*24) ))

	result "Days Remaining: $days_left"
elif [ "$check_type" = "valid" ]; then
	verify_return_code=$( echo "$output" | grep -E '^ *Verify return code:' | sed -n 1p | sed 's/^ *//' | tr -s ' ' | cut -d' ' -f4 )
	if [[ "$verify_return_code" -eq "0" ]]; then result "Valid SSL Certificate Found!" ; else result "No Certificate Found!" ; fi
fi
