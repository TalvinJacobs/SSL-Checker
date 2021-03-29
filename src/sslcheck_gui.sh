#!/bin/bash

for util in timeout openssl date zenity; do
	type "$util" >/dev/null || error "$uril is not found in \$PATH"
done


# Arguments
check_type=$(zenity --width=100 --height=100 --entry --title="Check type" --text="Enter check type(expire/valid): ")
host=$(zenity --width=100 --height=100 --entry --title="Hostname" --text="Enter hostname or IP:")
port=$(zenity --width=100 --height=100 --entry --title="Port" --text="Enter port nuber[1-65535] (default 443):")
[[ "$port" == "" ]] && port=443
domain=$(zenity --width=100 --height=100 --entry --title="Domain" --text="Enter Domain (default $host):")
[[ "$domain" == "" ]] && domain="$host"
searchTimeout=$(zenity --width=100 --height=100 --entry --title="Hostname" --text="Enter search timeout (default: 5)")
[[ $searchTimeout == "" ]] && searchTimeout=5

function error {
	zenity --warning --width=250 --height=100 --text="$1"
}

function result {
	zenity --info --width=250 --height=100 --text="$1"
}

# Input Validation
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
	expire_date=$(echo "$output" \
		| openssl x509 -noout -dates \
		| grep '^notAfter' | cut -d'=' -f2
	)
	expire_date_epoch=$(date -d "$expire_date" +%s) || error "Failed to get expiration"
	current_date_epoch=$(date +%s)
	days_left=$(( (expire_date_epoch - current_date_epoch)/(3600*24) ))

	result "$days_left days remaining"
elif [ "$check_type" = "valid" ]; then
	verify_return_code=$( echo "$output" | grep -E '^ *Verify return code:' | sed -n 1p | sed 's/^ *//' | tr -s ' ' | cut -d' ' -f4 )
	if [[ "$verify_return_code" -eq "0" ]]; then result "Valid SSL Certificate Found!" ; else result "No Certificate Found" ; fi
fi
