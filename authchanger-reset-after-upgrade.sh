#!/bin/bash
# 5/12/22 2:36 PM - Mike Gallagher

#############################
# DESCRIPTION
#############################

# This script creates three files:
# - /Library/Preferences/upgrade-check-control.plist
# - /Library/LaunchDaemons/"$organization".upgrade-check.plist
# - /private/var/$organization-upgrade-check.sh

# With these three files, this script will set the use the authchanger command to set the login window back to Jamf Connect after a major macOS upgrade.
# For reference: https://docs.jamf.com/jamf-connect/administrator-guide/Re-enabling_the_Login_Window_after_a_Major_macOS_Upgrade.html
# This script can be ran on computers using a Jamf Pro policy, in which the script parameter #4 can be used to set the organization name (that is used in the file paths). Alternatively, the org name can also be set under VARIABLES.

#############################
# VARIABLES
#############################

## Organzation name - best practice would be a single string (with no special characters), e.g. "jamf" vs "Jamf Software, Inc." Leave these blank to instead use the Jamf Pro Script Parameter #4
organization=""
if [[ -z $organization ]]; then
    organization="$4"
fi

#############################
# NO EDITS NECESSARY BELOW THIS LINE
#############################

# 1. Needs to create a LaunchDaemon that runs at load (which will be at every startup)

launchdaemonPlist="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
	<key>Label</key>
	<string>$organization.upgrade-check</string>
	<key>ProgramArguments</key>
	<array>
		<string>/private/var/$organization-upgrade-check.sh</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
</dict>
</plist>"

cat <<EOF >/Library/LaunchDaemons/"$organization".upgrade-check.plist
${launchdaemonPlist}
EOF

/usr/sbin/chown root:wheel /Library/LaunchDaemons/"$organization".upgrade-check.plist
/bin/chmod 644 /Library/LaunchDaemons/"$organization".upgrade-check.plist

# 2. Create the plist that holds the current major OS version

controlPlist="/Library/Preferences/upgrade-check-control.plist"
currentMajorVersion=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F. '{ print $1}')
/usr/bin/defaults write "$controlPlist" currentVersion -integer "$currentMajorVersion"

# 3. Create the script that the LaunchDaemon runs and that reads the PLIST

scriptPath="/private/var/$organization-upgrade-check.sh"

script='#!/bin/bash

    controlPlist="/Library/Preferences/upgrade-check-control.plist"

    ## Check if the plist exists
    if [ -e "$controlPlist" ]; then
        storedMajorVersion=$(/usr/bin/defaults read "$controlPlist" currentVersion 2>/dev/null)
        currentMajorVersion=$(/usr/bin/sw_vers -productVersion | grep -oh "[0-9][0-9]")

        ## Check if the current version is greater than the previously stored
        if [ "$currentMajorVersion" -gt "$storedMajorVersion" ]; then
             echo "Resetting authchanger." >> /tmp/upgrade-check.log
            echo "$currentMajorVersion" >> /tmp/upgrade-check.log
            echo "$storedMajorVersion" >> /tmp/upgrade-check.log
            ## reset authchanger to Jamf Connect
            /usr/local/bin/authchanger -reset -jamfconnect
            ## update storedMajorVersion
            /usr/bin/defaults write "$controlPlist" currentVersion "$currentMajorVersion"
            exit 0
        else
            ## If the value is equal or less than, exit the process without touching authchanger
            echo "Not an upgrade, carry on." >> /tmp/upgrade-check.log
            echo "$currentMajorVersion" >> /tmp/upgrade-check.log
            echo "$storedMajorVersion" >> /tmp/upgrade-check.log
            exit 0
        fi
    else
        echo "No plist file found." >> /tmp/upgrade-check.log
        exit 0
    fi
'

cat <<EOF >"$scriptPath"
${script}
EOF

/bin/chmod +x "$scriptPath"

exit 0
