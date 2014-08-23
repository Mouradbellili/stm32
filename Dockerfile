###
# STM32F4-Discovery Build and Test Environment
#
# VERSION         1.0
# DOCKER_VERSION  1.1.2
# AUTHOR          Iztok Starc <iz***.st***@gmail.com>
# DESCRIPTION     Build and Test Environment based on Ubuntu 14.04 LTS for the STM32F4-Discovery board.
#
#

###
# Usage
#
#
#
# You may pull the image from the repository (1) or build it yourself (2).
#
#
#
# 1. Pull the image from the repository
#
# 1.1 Prerequisites:
#
#    docker --version
#    Docker version 1.1.0 # Issues with version < 1.1.0
#
# 1.2 Basic Usage:
#
#    sudo docker pull istarc/stm32
#    CONTAINER_ID=$(sudo docker run -P -d --privileged=true istarc/stm32)
#    # Other run options:
#    # CONTAINER_ID=$(sudo docker run -P -d istarc/stm32) # /wo deploy capability
#    # sudo docker run -P -i -t istarc/stm32 /bin/bash # Interactive mode
#    sudo docker stop $CONTAINER_ID
#    # Stop and remove all containers
#    # sudo docker stop $(sudo docker ps -a -q) && sudo docker rm $(sudo docker ps -a -q)
#    # Remove all untagged images
#    # sudo docker rmi $(sudo docker images | grep "^<none>" | awk '{print $3}')
#
# 1.3 Build Existing Projects:
#
#    ssh -p $(sudo docker port $CONTAINER_ID 22 | cut -d ':' -f2) admin@localhost
#    Enter password: admin
#    cd ~/stm32/
#    make clean
#    make -j4
#
# 1.4 Deploy Existing Project:
#
#    ssh -p $(sudo docker port $CONTAINER_ID 22 | cut -d ':' -f2) admin@localhost
#    Enter password: admin
#    cd ~/stm32/examples/Template.mbed
#    make clean
#    make -j4
#    sudo make deploy
#
# 1.5 Create New STM32F4-Discovery Projects:
#
#  - http://istarc.wordpress.com
#  - https://github.com/istarc/stm32
#
# 1.6 Test Build Existing Projects via Buildbot:
#
#    firefox http://localhost:$(sudo docker port $CONTAINER_ID 8010 | cut -d ':' -f2)
#    Login U: admin P: admin (Upper right corner)
#    Click: Waterfall -> test-build -> [Use default options] -> Force Build
#    Check: Waterfall -> F5 to Refresh
#
#
#
# 2. Build the image 
#
# This is alternative to "1. Pull the image from the repository"
#
# 2.1 Prerequisites:
#
#    docker --version
#    Docker version 1.1.0 # Issues with version < 1.1.0
#
# 2.2 Install software dependencies
#
#    cd ~
#    wget https://github.com/istarc/stm32/blob/master/Dockerfile
#
# 2.3 Build the image
#
#    sudo docker build -t istarc/stm32 - < Dockerfile
#    
# 2.4 Usage: see 1.2 - 1.6

###
# Docker script
#
# 1. Initial docker image
from ubuntu:14.04

# 2. Install dependancies
# 2.1 Install platform dependancies
run export DEBIAN_FRONTEND=noninteractive
run sudo apt-get update -q
run sudo apt-get install -y supervisor sudo ssh openssh-server software-properties-common vim
# 2.2 Install project dependancies
run sudo add-apt-repository -y ppa:terry.guo/gcc-arm-embedded
run sudo apt-get update -q
run sudo apt-cache policy gcc-arm-none-eabi
# 2.2.1 GCC ARM
run sudo apt-get install -y build-essential git openocd gcc-arm-none-eabi=4-8-2014q2-0trusty10
# 2.2.2 Buildbot
run sudo apt-get install -y buildbot buildbot-slave
# 2.2.3 OpenOCD build dependancies
run sudo apt-get install -y libtool libftdi-dev libusb-1.0-0-dev automake pkg-config texinfo
# 2.2.4 Clone and init stm32 repository
run cd /home/admin; git clone https://github.com/istarc/stm32.git
run cd /home/admin/stm32; git submodule update --init

# 3. Add user admin with password "admin"
run useradd -s /bin/bash -m -d /home/admin -p sa1aY64JOY94w admin
run sed -Ei 's/adm:x:4:/admin:x:4:admin/' /etc/group
run sed -Ei 's/(\%admin ALL=\(ALL\) )ALL/\1 NOPASSWD:ALL/' /etc/sudoers

# 4. Setup ssh server
run mkdir -p /var/run/sshd
run /bin/echo -e "[program:sshd]\ncommand=/usr/sbin/sshd -D\n" > /etc/supervisor/conf.d/sshd.conf
expose 22

# 5. Setup buildbot master and workers
run mkdir -p /home/admin/stm32bb
run buildbot create-master /home/admin/stm32bb/master
run cp /home/admin/stm32/test/buildbot/master/master.cfg /home/admin/stm32bb/master/master.cfg
run buildslave create-slave /home/admin/stm32bb/slave localhost:9989 arm-none-eabi pass-MonkipofPaj1
run /bin/echo -e "[program:buildmaster]\ncommand=twistd --nodaemon --no_save -y buildbot.tac\ndirectory=/home/admin/stm32bb/master\nuser=admin\n" > /etc/supervisor/conf.d/buildbot.conf
run /bin/echo -e "[program:buildworker]\ncommand=twistd --nodaemon --no_save -y buildbot.tac\ndirectory=/home/admin/stm32bb/slave\nuser=admin\n" >> /etc/supervisor/conf.d/buildbot.conf
expose 8010

# 6. Build & Install OpenOCD from repository
run cd /home/admin; git clone git://openocd.git.sourceforge.net/gitroot/openocd/openocd
run cd /home/admin/openocd; ./bootstrap; ./configure --enable-maintainer-mode --disable-option-checking --disable-werror --prefix=/opt/openocd --enable-dummy --enable-usb_blaster_libftdi --enable-ep93xx --enable-at91rm9200 --enable-presto_libftdi --enable-usbprog --enable-jlink --enable-vsllink --enable-rlink --enable-stlink --enable-arm-jtag-ew; make; make install

# 7. Post-install
# 7.1 Setup folder & file privileges
run chown -R admin:admin /home/admin
run chmod o+rx /home
# 7.2 Commands to be executed when docker container starts
cmd ["/usr/bin/supervisord", "-n"]
