#!/bin/bash


if [ $(whoami) = root ];
then
  setenforce 0 2>/dev/null
  sed -i 's@SELINUX=enforcing@SELINUX=disabled@' /etc/sysconfig/selinux
  cat /etc/sysconfig/selinux | grep SELINUX=disabled >/dev/null

  if [ $? = 0 ];
  then
    swapoff -a
    sudo sed -i '/ swap / s/^/#/' /etc/fstab 
    cat /etc/fstab | grep "#/dev/mapper" >/dev/null

    if [ $? = 0 ];
    then
      systemctl disable firewalld && systemctl stop firewalld >/dev/null
      systemctl status firewalld | grep "Active: inactive" >/dev/null
                    
      if [ $? = 0 ];
      then
        echo 1 > /proc/sys/net/ipv4/ip_forward
        cat /etc/sysctl.conf | grep 'net.ipv4.ip_forward = 1' >/dev/null && cat /etc/sysctl.conf | grep 'net.bridge.bridge-nf-call-iptables = 1' >/dev/null

        if [ $? = 0 ];
        then
          cat /etc/modules-load.d/br_netfilter.conf | grep "br_netfilter" >/dev/null
            
          if [ $? = 0 ];
          then
            sysctl -p
            lsmod | grep br_netfilter
            echo "----------";
          else
            modprobe br_netfilter
            echo "br_netfilter" > /etc/modules-load.d/br_netfilter.conf
            sysctl -p
            lsmod | grep br_netfilter
            echo "----------"
          fi

          echo "NEXT STEP => crio-install.sh";

        else
          echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
          echo "net.bridge.bridge-nf-call-iptables = 1" >> /etc/sysctl.conf
          cat /etc/modules-load.d/br_netfilter.conf | grep "br_netfilter" >/dev/null          
          
          if [ $? = 0 ];
          then
            sysctl -p
            lsmod | grep br_netfilter
            echo"----------";
          else
            modprobe br_netfilter
            echo "br_netfilter" > /etc/modules-load.d/br_netfilter.conf
            sysctl -p
            lsmod | grep br_netfilter
            echo "----------"
          fi

          echo "NEXT STEP => crio-install.sh"
        fi;
      else
        echo "firewalld status NOT INACTIVE!!!"
      fi;
    else
      echo "swapoff FAILED!!!"
    fi;    
  else
    echo "selinux disabled FAILED!!!"
  fi;
else
  echo "user not ROOT"
fi
