#!/bin/bash
# 5/12/22 2:36 PM - Mike Gallagher

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

    ## Check if the plist file exists, and if a value can be pulled from it
    if [ -e "$controlPlist" ]; then
        storedMajorVersion=$(/usr/bin/defaults read "$controlPlist" currentVersion 2>/dev/null)
        currentMajorVersion=$(/usr/bin/sw_vers -productVersion | grep -oh "[0-9][0-9]")

        ## If the value is set to true, or there was no value set...
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
            ## If the value is set to anything other than true or not null, exit the process without touching authchanger
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
