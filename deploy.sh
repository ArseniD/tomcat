#!/bin/sh

# deploy.sh
# Script to shutdown tomcat and redeploy webapp

#Check the number of arguments
if [ "$#" -ne 2 ]
then
        echo "Missing arguments: webapp name and WAR file location"
        exit 1
fi

if [ -z "$1" ]
then
        echo "First argument cannot be empty"
        exit 1
fi

if [ -z "$2" ]
then
        echo "Second argument cannot be empty"
        exit 1
fi

tomcatHome="/opt/tomcat"
echo "Tomcat home: $tomcatHome"

# Get the process ID of tomcat
pid=$(ps h -C java -o "%p:%a" | grep catalina | cut -d: -f1)
if [ "$pid" -gt 0 ]
then
        echo "Shutting down tomcat PID $pid"

        # Shutdown tomcat
        #$tomcatHome/bin/shutdown.sh
        kill -9 $pid

        # Wait until tomcat is shutdown
        while kill -0 $pid > /dev/null; do sleep 1; done

fi

# remove the old webapp
echo "Removing webapp $1"
mv $tomcatHome/webapps/$1.war $tomcatHome/backup
rm -rf $tomcatHome/webapps/$1

# Copy the new WAR file to the webapps folder
cp $2 $tomcatHome/webapps/$1.war

# Change the permissions
chown tomcat:tomcat $tomcatHome/webapps/$1.war

# Start up tomcat
systemctl restart tomcat

# Finished
echo "redeployed successfully"
