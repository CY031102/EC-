#!/bin/bash

# 更新系统和安装必要的软件包
yum update -y
yum install -y tftp-server vim rsyslog policycoreutils-python-utils

# 配置TFTP服务
echo "Configuring TFTP service..."
sed -i '1,$d' /usr/lib/systemd/system/tftp.service
cat > /usr/lib/systemd/system/tftp.service <<EOF
[Unit]
Description=Tftp Server
Requires=tftp.socket
Documentation=man:in.tftpd

[Service]
ExecStart=/usr/sbin/in.tftpd -s /cisco/backup -c
StandardInput=socket

[Install]
Also=tftp.socket
EOF

mkdir -p /cisco/backup
chmod -R 777 /cisco/backup
chown -R nobody:nobody /cisco/backup

# 启动TFTP服务
systemctl enable tftp
systemctl start tftp
systemctl status tftp.service
systemctl status tftp.socket

# 配置并启动firewalld
echo "Configuring and starting firewalld..."
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --permanent --add-service=tftp
firewall-cmd --reload
firewall-cmd --list-all

# 配置SELinux
echo "Configuring SELinux for TFTP..."
semanage fcontext -a -t tftpdir_rw_t "/cisco/backup(/.*)?"
restorecon -Rv /cisco/backup
setsebool -P tftp_home_dir 1
sestatus

# 配置rsyslog服务
echo "Configuring rsyslog service..."
cp /etc/rsyslog.conf /etc/rsyslog.conf.backup
cat > /etc/rsyslog.d/cisco.conf <<EOF
# 加载UDP和TCP模块
module(load="imudp")
module(load="imtcp")

# 定义UDP和TCP输入
input(type="imudp" port="514")
input(type="imtcp" port="514")

#HQ1-R1
if \$msg contains 'HQ1-R1:' then {
    action(type="omfile" file="/var/log/cisco/HQ1-R1.log")
    stop
}

#HQ2-R1
if \$msg contains 'HQ2-R1:' then {
    action(type="omfile" file="/var/log/cisco/HQ2-R1.log")
    stop
}

#HQ1-Edge1
if \$msg contains 'HQ1-Edge1:' then {
    action(type="omfile" file="/var/log/cisco/HQ1-Edge1.log")
    stop
}

#RO1-Edge1
if \$msg contains 'RO1-Edge1:' then {
    action(type="omfile" file="/var/log/cisco/RO1-Edge1.log")
    stop
}

#HQ1-ASW1
if \$msg contains 'HQ1-ASW1:' then {
    action(type="omfile" file="/var/log/cisco/HQ1-ASW1.log")
    stop
}

#HQ1-ASW2
if \$msg contains 'HQ1-ASW2:' then {
    action(type="omfile" file="/var/log/cisco/HQ1-ASW2.log")
    stop
}

#HQ2-ASW1
if \$msg contains 'HQ2-ASW1:' then {
    action(type="omfile" file="/var/log/cisco/HQ2-ASW1.log")
    stop
}

#HQ2-ASW2
if \$msg contains 'HQ2-ASW2:' then {
    action(type="omfile" file="/var/log/cisco/HQ2-ASW2.log")
    stop
}

#RO1-ASW1
if \$msg contains 'RO1-ASW1:' then {
    action(type="omfile" file="/var/log/cisco/RO1-ASW1.log")
    stop
}

EOF

# 创建日志目录并设置权限
mkdir -p /var/log/cisco
chmod 755 /var/log/cisco

# 重新启动rsyslog服务
systemctl restart rsyslog
ss -tuln | grep :514

# 配置并启动firewalld
echo "Configuring firewalld for rsyslog..."
firewall-cmd --permanent --add-port=514/udp
firewall-cmd --permanent --add-port=514/tcp
firewall-cmd --reload
firewall-cmd --list-all

# 配置SELinux标签
echo "Configuring SELinux for rsyslog..."
setsebool -P nis_enabled 1
semanage fcontext -a -t var_log_t "/var/log/cisco(/.*)?"
restorecon -Rv /var/log/cisco
getsebool nis_enabled

# 重新启动rsyslog服务
systemctl restart rsyslog

echo "Configuration completed successfully."
