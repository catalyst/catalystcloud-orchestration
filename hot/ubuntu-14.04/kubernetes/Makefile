KEY_PAIR ?=
NETWORK_NAME ?= k8s-network
MASTER_NAME ?= k8s-master
MINION_NAME ?= k8s-minion
NETWORK_EXISTS = $(shell openstack stack list | grep $(NETWORK_NAME))
MASTER_EXISTS = $(shell openstack stack list | grep $(MASTER_NAME))
MINONS_EXIST = $(shell openstack stack list | grep $(MINION_NAME))
START ?= 1
FINISH ?= 3
NUMBERS := $(shell seq $(START) $(FINISH))
ADDRS := $(shell seq 1 254)

ifndef KEY_PAIR
    $(error KEY_PAIR has not been supplied eg: make <action> KEY_PAIR=your-key)
endif

all: build

clean_minions:
	# $(foreach var,$(NUMBERS), openstack stack delete --yes $(MINION_NAME)$(var);)
	for MINION in  $(NUMBERS) ; \
	do \
	MINONS_EXIST=`openstack stack list 2>/dev/null | grep $(MINION_NAME)$${MINION}`; \
	if [ -n "$$MINONS_EXIST" ] ; then \
  openstack stack delete --yes $(MINION_NAME)$${MINION}; \
	while [ -n "$$MINONS_EXIST" ] ; \
	do \
    echo "waiting ..."; \
    openstack stack list 2>/dev/null | grep $(MINION_NAME); \
    sleep 3; \
    MINONS_EXIST=`openstack stack list 2>/dev/null | grep $(MINION_NAME)$${MINION}` ; \
	done ; \
	fi ; \
	done ; true
	openstack stack list

clean: clean_minions
ifneq "$(strip $(MASTER_EXISTS))" ""
	openstack stack delete --yes $(MASTER_NAME)
	MASTER_EXISTS=`openstack stack list 2>/dev/null | grep $(MASTER_NAME)`; \
	while [ -n "$$MASTER_EXISTS" ] ; \
	do \
    echo "waiting ..."; \
    openstack stack list 2>/dev/null | grep $(MASTER_NAME); \
    sleep 3; \
    MASTER_EXISTS=`openstack stack list 2>/dev/null | grep $(MASTER_NAME)` ; \
	done ; true
	openstack stack list
endif
	openstack stack list

clean_network:
ifneq "$(strip $(NETWORK_EXISTS))" ""
	openstack stack delete --yes  $(NETWORK_NAME)
	NETWORK_EXISTS=`openstack stack list 2>/dev/null | grep $(NETWORK_NAME)`; \
	while [ -n "$$NETWORK_EXISTS" ] ; \
	do \
    echo "waiting ..."; \
    openstack stack list 2>/dev/null | grep $(NETWORK_NAME); \
    sleep 3; \
    NETWORK_EXISTS=`openstack stack list 2>/dev/null | grep $(NETWORK_NAME)` ; \
	done ; true
	openstack stack list
endif
	openstack stack list

realclean: clean clean_network

build_network:
ifeq "$(strip $(NETWORK_EXISTS))" ""
	openstack stack create -t templates/kubernetes-network.yaml -e templates/environment.yaml --parameter key-pair=$(KEY_PAIR) $(NETWORK_NAME)
	# wait for 5 seconds so atleast the network is up
	sleep 5
endif
	NETWORK_EXISTS=`openstack stack list 2>/dev/null | grep $(NETWORK_NAME) | grep CREATE_COMPLETE`; \
	while [ -z "$$NETWORK_EXISTS" ] ; \
	do \
    echo "waiting ..."; \
    openstack stack list 2>/dev/null | grep $(NETWORK_NAME); \
    sleep 3; \
    NETWORK_EXISTS=`openstack stack list 2>/dev/null | grep $(NETWORK_NAME) | grep CREATE_COMPLETE` ; \
	done ; true
	openstack stack output show $(NETWORK_NAME) private_net_id


build_master:
ifeq "$(strip $(MASTER_EXISTS))" ""
	NET_ID=`openstack network show $(NETWORK_NAME) -c id -f value`; \
	openstack stack create -t templates/kubernetes-master.yaml -e templates/environment.yaml --parameter key-pair=$(KEY_PAIR) --parameter private_net_id=$${NET_ID} $(MASTER_NAME)
	# wait for 15 seconds so atleast the network is up
	sleep 15
endif
	MASTER_EXISTS=`openstack stack list 2>/dev/null | grep $(MASTER_NAME) | grep CREATE_COMPLETE`; \
	while [ -z "$$MASTER_EXISTS" ] ; \
	do \
    echo "waiting ..."; \
    openstack stack list 2>/dev/null | grep $(MASTER_NAME); \
    sleep 3; \
    MASTER_EXISTS=`openstack stack list 2>/dev/null | grep $(MASTER_NAME) | grep CREATE_COMPLETE` ; \
	done ; true
	openstack stack output show $(MASTER_NAME) floating_ip

build_minions: build_master
	# $(foreach var,$(NUMBERS), openstack stack create -t templates/kubernetes-minion.yaml -e templates/environment.yaml $(MINION_NAME)$(var);)
	NET_ID=`openstack network show $(NETWORK_NAME) -c id -f value`; \
	echo "Minions to build: $(START)/$(FINISH)/$(NUMBERS)"; \
	for MINION in  $(NUMBERS) ; \
	do \
	MINONS_EXIST=`openstack stack list 2>/dev/null | grep $(MINION_NAME)$${MINION}`; \
	if [ -z "$$MINONS_EXIST" ] ; then \
	openstack stack create -t templates/kubernetes-minion.yaml -e templates/environment.yaml --parameter key-pair=$(KEY_PAIR) --parameter private_net_id=$${NET_ID} $(MINION_NAME)$${MINION}; \
	while [ -z "$$MINONS_EXIST" ] ; \
	do \
    echo "waiting ..."; \
    openstack stack list 2>/dev/null | grep $(MINION_NAME); \
    sleep 3; \
    MINONS_EXIST=`openstack stack list 2>/dev/null | grep $(MINION_NAME)$${MINION} | grep CREATE_COMPLETE` ; \
	done ; \
	fi ; \
	done ; true
	openstack stack list
	openstack stack output show $(MASTER_NAME) floating_ip


build: build_network build_master build_minions


stop_tunnel: build_master
	TUNNEL=`ps axf | grep ssh | grep localhost:8080 | grep -v grep | awk '{print $$1}'`; \
	if [ -n "$$TUNNEL" ] ; then \
	echo "Tunnel exists - removing - $$TUNNEL"; \
	kill -9 $$TUNNEL; \
	fi ;

start_tunnel: build_master stop_tunnel
	# "Launch tunnel for 8080 ..."
	which kubectl || (echo "kubectl command not found in PATH"; exit -1;)
	MASTER_IP=`openstack stack output show $(MASTER_NAME) floating_ip | tr -d '"'`; \
	ssh -f -N ubuntu@$${MASTER_IP} -L 8080:localhost:8080

start_dns: build_master
	# "Launch DNS service ..."
	kubectl --server="http://localhost:8080" create -f templates/dns-addon.yaml
	# "You must wait for DNS to settle before doing make test_dns"

stop_dns:
	# "Stop DNS service ..."
	kubectl --server="http://localhost:8080" delete -f templates/dns-addon.yaml

start_ui: build_master
	kubectl --server="http://localhost:8080" create -f templates/kube-ui-rc.yaml; \
	kubectl --server="http://localhost:8080" create -f templates/kube-ui-svc.yaml
	echo "When the pod is up and running (takes a while), go to https://10.100.0.1/ui"

stop_ui:
	echo "Stopping UI ..."
	kubectl --server="http://localhost:8080" delete -f templates/kube-ui-svc.yaml; \
	kubectl --server="http://localhost:8080" delete -f templates/kube-ui-rc.yaml

rm_hosts:
	for SUBNET in  40 41 ; \
	do \
	for ADR in  $(ADDRS) ; \
	do \
	ssh-keygen -f "/home/$${USER}/.ssh/known_hosts" -R 150.242.$${SUBNET}.$${ADR} ; \
	done; \
	done; true

test_dns:
	CONTAINER_EXISTS=`kubectl --server="http://localhost:8080" get pods  busybox 2>/dev/null` ; \
	if [ -z "$${CONTAINER_EXISTS}" ]; then \
	kubectl --server="http://localhost:8080" create -f templates/busybox.yaml ; \
	CONTAINER_EXISTS=`kubectl --server="http://localhost:8080" get pods  busybox 2>/dev/null | grep Running`; \
	while [ -z "$$CONTAINER_EXISTS" ] ; \
	do \
    echo "waiting ..."; \
    kubectl --server="http://localhost:8080" get pods  busybox; \
    sleep 3; \
    CONTAINER_EXISTS=`kubectl --server="http://localhost:8080" get pods  busybox 2>/dev/null | grep Running` ; \
	done ; \
	fi
	kubectl --server="http://localhost:8080" exec busybox -- cat /etc/resolv.conf
	kubectl --server="http://localhost:8080" exec busybox -- nslookup kubernetes.default.svc.cluster.local
	kubectl --server="http://localhost:8080" exec busybox -- nslookup busybox
	kubectl --server="http://localhost:8080" exec busybox -- nslookup www.ibm.com
	kubectl --server="http://localhost:8080" delete -f templates/busybox.yaml
	CONTAINER_EXISTS=`kubectl --server="http://localhost:8080" get pods  busybox 2>/dev/null`; \
	while [ -n "$$CONTAINER_EXISTS" ] ; \
	do \
    echo "waiting ..."; \
    sleep 3; \
    CONTAINER_EXISTS=`kubectl --server="http://localhost:8080" get pods  busybox 2>/dev/null` ; \
    if [ -z "$$CONTAINER_EXISTS" ]; then \
    kubectl --server="http://localhost:8080" get pods  busybox; \
    fi; \
	done; true
