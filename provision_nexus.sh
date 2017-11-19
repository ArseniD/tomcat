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
# Install Nexus
########################
mkdir /usr/local/sonatype/
wget http://download.sonatype.com/nexus/3/latest-unix.tar.gz -O /usr/local/sonatype/latest-unix.tar.gz 
tar xzf /usr/local/sonatype/latest-unix.tar.gz -C /usr/local/sonatype/
NEXUS_LATEST=$(ls /usr/local/sonatype/ | grep nexus-3)
ln -s /usr/local/sonatype/$NEXUS_LATEST /usr/local/nexus
rm -f /usr/local/sonatype/latest-unix.tar.gz

echo "Setup Nexus Environment Variables"
cat <<EOT >> /etc/profile.d/nexus.sh
#!/bin/bash
export NEXUS_HOME=/usr/local/nexus
export PATH=$PATH:$NEXUS_HOME/bin
EOT
chmod +x /etc/profile.d/nexus.sh
source /etc/profile.d/nexus.sh


########################
# Configuring Nexus
########################
useradd nexus
chown -R nexus:nexus /usr/local/sonatype
sed -i 's/#run_as_user=""/run_as_user="nexus"/g' $NEXUS_HOME/bin/nexus.rc

cat <<EOF > /etc/systemd/system/nexus.service
[Unit]
Description=nexus service
After=network.target
   
[Service]
Type=forking
LimitNOFILE=65536
ExecStart=/usr/local/nexus/bin/nexus start
ExecStop=/usr/local/nexus/bin/nexus stop
ExecRestart=/usr/local/nexus/bin/nexus restart
ExecReload=/usr/local/nexus/bin/nexus force-reload
User=nexus
Restart=on-abort
   
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
    server 127.0.0.1:8081 fail_timeout=0;
}

server {
    listen 80;
    listen [::]:80 default ipv6only=on;
    server_name nexus;

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
systemctl start nexus && systemctl enable nexus

reboot

echo "Success! Rebooting.."
exit 0
