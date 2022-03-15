#!/bin/bash

cat /etc/yum.repos.d/kubernetes.repo | grep "[kubernetes]" >/dev/null

if [ $? = 0 ]
then
  echo "kubernetes.repo CORRECT!"
else
  echo "[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl" > /etc/yum.repos.d/kubernetes.repo 
  echo "kubernetes.repo CORRECT!"
fi



rpm -qa | grep 'kubeadm\|kubelet\|kubectl' >/dev/null
if [ $? = 0 ];
then
  echo "kubeadm kubelet kubectl ALREADY EXIST";
else
  yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
fi



if [ $? = 0 ];
then
  cat /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf | grep "KUBELET_CGROUP" >/dev/null
  
  if [ $? = 0 ];
  then
    echo "KUBELET_CGROUP ALREADY ADDED!!!"
  else
    sed -i 's@ExecStart=/usr/bin/kubelet@ExecStart=/usr/bin/kubelet $KUBELET_CGROUP_ARGS'
    echo "Environment="KUBELET_CGROUP_ARGS=--cgroup-driver=systemd" ">> /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf
  fi;
else
  echo "kubelet kubeadm kubectl installed FAILED!!!"
  exit 
fi


systemctl restart kubelet
systemctl enable kubelet
systemctl status -l kubelet | grep "loaded" >/dev/null

if [ $? = 0 ]
then
  while true 
  do
    read -p "###master(m) or worker(w)?" ans
    case ${ans^} in
    M)
      yum install -y haproxy keepalived >/dev/null
      rpm -qa | grep haproxy >/dev/null

      if [ $? = 0 ];
      then
        echo "#---------------------------------------------------------------------
# Example configuration for a possible web application.  See the
# full configuration options online.
#
#   http://haproxy.1wt.eu/download/1.4/doc/configuration.txt
#
#---------------------------------------------------------------------

#---------------------------------------------------------------------
# Global settings
#---------------------------------------------------------------------
global
    # to have these messages end up in /var/log/haproxy.log you will
    # need to:
    #
    # 1) configure syslog to accept network log events.  This is done
    #    by adding the '-r' option to the SYSLOGD_OPTIONS in
    #    /etc/sysconfig/syslog
    #
    # 2) configure local2 events to go to the /var/log/haproxy.log
    #   file. A line like the following can be added to
    #   /etc/sysconfig/syslog
    #
    #    local2.*                       /var/log/haproxy.log
    #
    log         127.0.0.1 local2

    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4000
    user        haproxy
    group       haproxy
    daemon

    # turn on stats unix socket
    stats socket /var/lib/haproxy/stats

#---------------------------------------------------------------------
# common defaults that all the 'listen' and 'backend' sections will
# use if not designated in their block
#---------------------------------------------------------------------
defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          1m
    timeout server          1m
    timeout http-keep-alive 10s
    timeout check           10s
    maxconn                 3000

#---------------------------------------------------------------------
# kubernetes apiserver frontend which proxys to the backends
#---------------------------------------------------------------------
frontend kubernetes
    mode                 tcp
    bind                 *:16443
    option               tcplog
    default_backend      kubernetes-apiserver

#---------------------------------------------------------------------
# round robin balancing between the various backends
#---------------------------------------------------------------------
backend kubernetes-apiserver
    mode        tcp
    option      tcp-check
    balance     roundrobin
    server  m1 192.168.222.101:6443 check
    server  m2 192.168.222.102:6443 check
    server  m3 192.168.222.103:6443 check" > /etc/haproxy/haproxy.cfg 
        systemctl start haproxy
        systemctl enable haproxy

        systemctl  status -l haproxy | grep Active;
      else
        echo "haproxy installed FAILED!!!"
        exit
      fi

      rpm -qa | grep keepalived

      if [ $? = 0 ];
      then
        read -p "###Key your hostname:
" ANS
        read -p "###Key priority(150/125/100/75...)" PR
        echo "! Configuration File for keepalived

global_defs {
   router-id $ANS
}

vrrp_instance VI_1 {
    state MASTER
    interface ens192
    virtual_router_id 51
    priority $PR
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        192.168.222.100        #虛擬IP : VIP
    }
}
" >/etc/keepalived/keepalived.conf
        systemctl start keepalived
        systemctl enable keepalived
        
        systemctl status -l keepalived >/dev/null

        if [ $? = 0 ];
        then 
          read -p "Are u master1?(y/m)" YM
          if [ ${YM,} = y ];
          then 
            kubeadm init --cri-socket="/var/run/crio/crio.sock" --control-plane-endpoint "192.168.222.100:6443" --upload-certs --service-cidr 10.98.0.0/24 --pod-network-cidr 10.244.0.0/16 --apiserver-advertise-address 192.168.222.101 
            echo " ## remember tokens & do:"
            echo "    mkdir -p \$HOME/.kube"
            echo "    sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config"
            echo "    sudo chown \$(id -u):\$(id -g) $HOME/.kube/config;"
          else
            echo "key control-plane token from master1 & SCP .kube"
          fi;
        else
          echo "keepalived disabled!!!"
        fi;
      else
        echo "keepalived installed FAILED!!!"
      fi
    exit ;;
    W)
      echo "Key token from master1~"
      exit ;;
    *)
      echo "Please key m/M or w/W !!!"
    esac
  done
 
else
  echo "kubelet NOT LOADED!!!"
  exit
fi

