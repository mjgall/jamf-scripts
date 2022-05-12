#!/bin/bash
#7/23/21 4:34 PM - Mike Gallagher

echo "Server URL:"
read -r JamfProURL
# JamfProURL="https://instance.jamfcloud.com"

echo "JSS API username for $JamfProURL:"
read -r username

echo "JSS API password for $username:"
read -r -s password
# Generate creds using https://www.jamf.com/developers/apis/classic/code-samples/
creds=$(printf "$username":"$password" | iconv -t ISO-8859-1 | base64 -i -)

## payload domain to be looking for
echo "Payload domain to look for:"
read -r lookingFor
# lookingFor="com.apple.system-extension-policy"

## name of csv to create on the Desktop (excluding .csv)
echo "Name of csv file to output on your Desktop (without .csv):"
read -r desiredFilename
# desiredFilename="test"

# Get a list of Config Profile
listOfmacOSConfigProfileIDs=$(curl -s -H "Authorization: Basic $creds" -X GET -H "Accept: text/xml" "$JamfProURL/JSSResource/osxconfigurationprofiles" | xmllint --format - | awk -F '[<>]' '/<\/id>/{print $3}')

echo "Profile Id, Profile Name, Site" > ~/Desktop/"$desiredFilename".csv

echo "Looking for profiles...."

## Loop over all profiles and if they contain what we're looking for echo them and add them to the csv
for macOSProfileID in $listOfmacOSConfigProfileIDs
	
do
	profile=$(curl -s -H "Authorization: Basic $creds" -X GET -H "Accept: text/xml" "$JamfProURL/JSSResource/osxconfigurationprofiles/id/$macOSProfileID" | sed 's/\&/\$amp\;/g' | xmllint --format -)
	profile_site=$(echo $profile | sed 's/\&/\$amp\;/g' | xmllint --xpath 'os_x_configuration_profile/general/site/name/text()' -)
	profile_name=$(echo $profile | sed 's/\&/\$amp\;/g' | xmllint --xpath 'os_x_configuration_profile/general/name/text()' -)
	payload=$(echo $profile | sed 's/\&/\$amp\;/g'| xmllint --xpath 'os_x_configuration_profile/general/payloads/text()' -)
	
	if [[ "$payload" == *"$lookingFor"* ]]; then
		echo "Found ID: $macOSProfileID Name: $profile_name in the $profile_site site!"
		echo "$macOSProfileID,$profile_name,$profile_site" >> ~/Desktop/"$desiredFilename".csv
	fi

done
