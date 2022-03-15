#!/bin/bash

export VERSION=1.23
export OS=CentOS_7

#裝fuse3
if [ $(whoami) = "root" ] ;
then
  wget https://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/e/epel-release-7-14.noarch.rpm
  rpm -Uvh epel-release-7*.rpm
  yum install -y fuse3 
  rpm -qa | grep fuse > /dev/null

#裝container-seliux 
  if [ $? = 0 ];
  then
    wget http://mirror.centos.org/centos/7/extras/x86_64/Packages/container-selinux-2.119.2-1.911c772.el7_8.noarch.rpm
    yum install -y container-selinux-2.119.2-1.911c772.el7_8.noarch.rpm
    rpm -qa | grep container-selinux >/dev/null
   
#裝cri-o
    if [ $? = 0 ];
    then
      curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable.repo https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/devel:kubic:libcontainers:stable.repo
      curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.repo https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$VERSION/$OS/devel:kubic:libcontainers:stable:cri-o:$VERSION.repo
      yum install -y cri-o
      rpm -qa | grep cri-o

#啟用crio
      if [ $? = 0 ];
      then
        systemctl daemon-reload
        systemctl enable crio --now
        systemctl status crio | grep active >/dev/null

#最後check
        if [ $? =  0 ];
        then
          cat /etc/crictl.yaml | grep "image-endpoint: unix:///var/run/crio/crio.sock"
          if [ $? = 0 ]
          then
            echo "crio install all COMPLETED!!!"
            echo "            fuse3-libs-3.6.1-2.el7.x86_64
            container-selinux-2.119.2-1.911c772.el7_8.noarch
            cri-o-1.23.1-1.1.el7.x86_64";
          else
            echo "image-endpoint: unix:///var/run/crio/crio.sock" >> /etc/crictl.yaml
            echo "crio install all COMPLETED!!!"
            echo "            fuse3-libs-3.6.1-2.el7.x86_64
            container-selinux-2.119.2-1.911c772.el7_8.noarch
            cri-o-1.23.1-1.1.el7.x86_64"
          fi;
        else
          echo "crio DISABLED!!!"
        fi;
      else
        echo "cri-o installed FAILED!!!"
      fi;
    else
      echo "container-selinux installed FAILED!!!"
    fi; 
  else
    echo "fuse installed FAILED!!!"
  fi; 
else
  echo "user not ROOT!!!"
fi
