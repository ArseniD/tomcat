#!/bin/bash


########################
# Install Java
########################
echo "Installing Java"
yum -y install git net-tools vim unzip
cd /opt/
wget --no-cookies --no-check-certificate --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/8u151-b12/e758a0de34e24606bca991d704f6dcbf/jdk-8u151-linux-x64.tar.gz"
tar xzf jdk-8u151-linux-x64.tar.gz
rm -f jdk-8u151-linux-x64.tar.gz
cd /opt/jdk1.8.0_151/
alternatives --install /usr/bin/java java /opt/jdk1.8.0_151/bin/java 2
alternatives --config java <<< "2"
alternatives --install /usr/bin/jar jar /opt/jdk1.8.0_151/bin/jar 2
alternatives --install /usr/bin/javac javac /opt/jdk1.8.0_151/bin/javac 2
alternatives --set jar /opt/jdk1.8.0_151/bin/jar
alternatives --set javac /opt/jdk1.8.0_151/bin/javac

echo "Check java version"
java -version

echo "Setup Java Environment Variables"
cat <<EOT >> /etc/profile.d/java.sh
#!/bin/bash
export JAVA_HOME=/opt/jdk1.8.0_151
export JRE_HOME=/opt/jdk1.8.0_151/jre
export PATH=$PATH:/opt/jdk1.8.0_151/bin:/opt/jdk1.8.0_151/jre/bin
EOT

chmod +x /etc/profile.d/java.sh
source /etc/profile.d/java.sh

echo "Check JAVA_HOME"
echo $JAVA_HOME

cat <<EOT >> ~/.bash_profile
export JAVA_HOME=/opt/jdk1.8.0_151
export JRE_HOME=/opt/jdk1.8.0_151/jre
export PATH=$PATH:/opt/jdk1.8.0_151/bin:/opt/jdk1.8.0_151/jre/bin
EOT


########################
# Install Tomcat
########################
groupadd tomcat
useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat
cd /opt/
wget http://www-us.apache.org/dist/tomcat/tomcat-9/v9.0.1/bin/apache-tomcat-9.0.1.tar.gz
tar -xzvf apache-tomcat-9.0.1.tar.gz
mv apache-tomcat-9.0.1/* tomcat/
rm -f apache-tomcat-9.0.1.tar.gz


########################
# Configuring Tomcat
########################
mkdir /opt/tomcat/backup
sed -i '/<\/tomcat-users>/ i\<user name="tomcat" password="tomcat" roles="admin-gui,manager-gui,manager-script" />' /opt/tomcat/conf/tomcat-users.xml

cat <<\EOF > /opt/tomcat/bin/deploy.sh
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
EOF

chmod +x /opt/tomcat/deploy.sh
chown -hR tomcat:tomcat tomcat

cat <<EOF > /etc/systemd/system/tomcat.service
[Unit]
Description=Apache Tomcat 9 Servlet Container
After=syslog.target network.target

[Service]
User=tomcat
Group=tomcat
Type=forking
Environment=CATALINA_PID=/opt/tomcat/tomcat.pid
Environment=CATALINA_HOME=/opt/tomcat
Environment=CATALINA_BASE=/opt/tomcat
ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF


########################
# Install Nginx
########################
echo "Installing nginx"
yum -y install nginx > /dev/null 2>&1


########################
# Configuring nginx
########################
echo "Configuring nginx"
sed -e 's/80/8088/' -i /etc/nginx/nginx.conf
cat > /etc/nginx/conf.d/sonar.conf <<\EOF
client_max_body_size 100M;

upstream app_server {
    server 127.0.0.1:8080 fail_timeout=0;
}

server {
    listen 80;
    listen [::]:80 default ipv6only=on;
    server_name tomcat;

    location / {
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $http_host;
        proxy_redirect off;

        if (!-f $request_filename) {
            proxy_pass http://app_server;
            break;
        }
    }
}
EOF

systemctl start  nginx && systemctl enable nginx
systemctl start tomcat && systemctl enable tomcat

echo "Success! Rebooting.."
reboot

exit 0
