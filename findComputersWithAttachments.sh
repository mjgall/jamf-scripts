#!/bin/bash

#1/20/22 - Mike Gallagher (mike.gallagher@jamf.com)

echo "Enter server URL:"
read serverUrl
echo "Enter username for $serverUrl:"
read username
echo "Enter password for $username (will not be visible while typing):"
read -s password
creds=$(printf "$username:$password" | iconv -t ISO-8859-1 | base64 -i -)

echo "Getting all computers..."
computers=$(curl -sk -H "Authorization: Basic $creds" -H "accept: text/xml" $serverUrl/JSSResource/computers -X GET | xmllint --format - | awk -F '[<>]' '/<id>/{print $3}')

computersWithAttachments=()

echo "Checking each computer for attachments..."
for computerId in ${computers[@]}; do

    attachments=$(curl -sk -H "Authorization: Basic $creds" -H "accept: text/xml" $serverUrl/JSSResource/computers/id/$computerId -X GET | xmllint --format - | xmllint --xpath "/computer/purchasing/attachments/child::*" - 2>/dev/null)
    if [[ $attachments ]]; then
        computersWithAttachments=(${computersWithAttachments[@]} "$computerId")
    fi

done

echo "The following computer IDs have attachments:"

for value in "${computersWithAttachments[@]}"; do
    echo $value
done

exit 0
