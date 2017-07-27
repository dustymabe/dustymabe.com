---
title: "Non Deterministic docker Networking and Source Based IP Routing"
tags:
date: "2016-05-25"
published: true
---

.. Non Deterministic docker Networking and Source Based IP Routing
.. ===============================================================

Introduction
------------

In the open source `docker engine`_ a new networking model was
introduced_ in ``docker`` 1.9 which enabled the creation of separate
**"networks"** for containers to be attached to. This, however, can
lead to a nasty little problem where a port that is supposed to be
exposed on the host isn't accessible from the outside. There are a 
few bug_ reports_ that are related to this issue.

.. _docker engine: https://github.com/docker/docker
.. _introduced: https://blog.docker.com/2015/11/docker-multi-host-networking-ga/
.. _bug: https://github.com/docker/docker/issues/21741
.. _reports: https://github.com/docker/compose/issues/3055

Cause
-----

This problem happens because ``docker`` wires up all of these containers 
to each other and the various **"networks"** using port forwarding/NAT via
``iptables``. Let's take a popular example application which exhibits
the problem, the `Docker 3rd Birthday Application`_, and show what the problem 
is and why it happens.

.. _Docker 3rd Birthday Application: https://github.com/docker/docker-birthday-3

We'll clone the git repo first and then check out the latest commit as of 
2016-05-25::

    # git clone https://github.com/docker/docker-birthday-3
    # cd docker-birthday-3/
    # git checkout 'master@{2016-05-25}'
    ...
    HEAD is now at 4f2f1c9... Update Dockerfile

Next we'll bring up the application::

    # cd example-voting-app/
    # docker-compose up -d 
    Creating network "examplevotingapp_front-tier" with the default driver
    Creating network "examplevotingapp_back-tier" with the default driver
    Creating db
    Creating redis
    Creating examplevotingapp_voting-app_1
    Creating examplevotingapp_worker_1
    Creating examplevotingapp_result-app_1

So this created two networks and brought up several containers to host our application.
Let's poke around to see what's there::

    # docker network ls
    NETWORK ID          NAME                          DRIVER
    23c96b2e1fe7        bridge                        bridge              
    cd8ecb4c0556        examplevotingapp_front-tier   bridge              
    5760e64b9176        examplevotingapp_back-tier    bridge              
    bce0f814fab1        none                          null                
    1b7e62bcc37d        host                          host
    #
    # docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}"
    NAMES                           IMAGE                         PORTS
    examplevotingapp_result-app_1   examplevotingapp_result-app   0.0.0.0:5001->80/tcp
    examplevotingapp_voting-app_1   examplevotingapp_voting-app   0.0.0.0:5000->80/tcp
    redis                           redis:alpine                  0.0.0.0:32773->6379/tcp
    db                              postgres:9.4                  5432/tcp
    examplevotingapp_worker_1       manomarks/worker              

So two networks were created and the containers running the application were brought up.
Looks like we should be able to connect to the ``examplevotingapp_voting-app_1`` 
application on the host port ``5000`` that is bound to all interfaces. Does it work?::

    # ip -4 -o a
    1: lo    inet 127.0.0.1/8 scope host lo\       valid_lft forever preferred_lft forever
    2: eth0    inet 192.168.121.98/24 brd 192.168.121.255 scope global dynamic eth0\       valid_lft 2921sec preferred_lft 2921sec
    3: docker0    inet 172.17.0.1/16 scope global docker0\       valid_lft forever preferred_lft forever
    106: br-cd8ecb4c0556    inet 172.18.0.1/16 scope global br-cd8ecb4c0556\       valid_lft forever preferred_lft forever
    107: br-5760e64b9176    inet 172.19.0.1/16 scope global br-5760e64b9176\       valid_lft forever preferred_lft forever
    #
    # curl --connect-timeout 5 192.168.121.98:5000 &>/dev/null && echo success || echo failure
    failure
    # curl --connect-timeout 5 127.0.0.1:5000 &>/dev/null && echo success || echo failure
    success

Does it work? Yes and no? 

That's right. There is something complicated going on with the networking here.
I can connect from ``localhost`` but can't connect to the public IP of the host.
Docker wires things up in iptables so that things can go into and out
of containers following a strict set of rules; see the `iptables output`_
if you are interested. This works fine if you only have one network interface 
per container but can break down when you have multiple interfaces attached to 
a container.

.. _iptables output: http://dustymabe.com/content/2016-05-25/iptables.txt

Let's jump in to the ``examplevotingapp_voting-app_1`` container and
check out some of the networking::

    # docker exec -it examplevotingapp_voting-app_1 /bin/sh
    /app # ip -4 -o a
    1: lo    inet 127.0.0.1/8 scope host lo\       valid_lft forever preferred_lft forever
    112: eth1    inet 172.18.0.2/16 scope global eth1\       valid_lft forever preferred_lft forever
    114: eth0    inet 172.19.0.4/16 scope global eth0\       valid_lft forever preferred_lft forever
    /app # 
    /app # ip route show
    default via 172.19.0.1 dev eth0 
    172.18.0.0/16 dev eth1  src 172.18.0.2 
    172.19.0.0/16 dev eth0  src 172.19.0.4

So there is a clue. We have two interfaces, but our default route is
going to go out of the ``eth0`` on the ``172.19.0.0/16`` network. It
just so happens that our ``iptables`` rules (see linked iptables
output from above) performed DNAT for ``tcp dpt:5000 to:172.18.0.2:80``.
So traffic from the outside is going to come in to this container on
the ``eth1`` interface but leave it on the ``eth0`` interface, which
doesn't play nice with the ``iptables`` rules ``docker`` has set up.

We can prove that here by asking what route we will take when a packet
leaves the machine::


    /app # ip route get 10.10.10.10 from 172.18.0.2
    10.10.10.10 from 172.18.0.2 via 172.19.0.1 dev eth0

Which basically means it will leave from ``eth0`` even though it came
in on ``eth1``. The Docker documentation was updated to try to explain
the behavior when multiple interfaces are attached to a container in `this`_ git
commit.

.. _this: https://github.com/docker/docker/pull/22086/files


Test Out Theory Using Source Based IP Routing
---------------------------------------------

To test out the theory on this we can use source based IP routing
(some reading on that `here`_). Basically the idea is that we create
policy rules that make IP traffic leave on the same interface it
came in on.

.. _here: http://www.tldp.org/HOWTO/Adv-Routing-HOWTO/lartc.rpdb.simple.html


To perform the test we'll need our container to be privileged
so we can add routes. Modify the ``docker-compose.yml`` to add
``privileged: true`` to the ``voting-app``::

    services:
      voting-app:
        build: ./voting-app/.
        volumes:
         - ./voting-app:/app
        ports:
          - "5000:80"
        networks:
          - front-tier
          - back-tier
        privileged: true

Take down and bring up the application::

    # docker-compose down
    ...
    # docker-compose up -d
    ...


Exec into the container and create a new policy rule for packets
originating from the ``172.18.0.0/16`` network. Tell packets matching
this rule to look up routing table ``200``::

    # docker exec -it examplevotingapp_voting-app_1 /bin/sh
    /app # ip rule add from 172.18.0.0/16 table 200

Now add a default route for ``172.18.0.1`` to routing table ``200``.
Show the routing table after that and the rules as well::

    /app # ip route add default via 172.18.0.1 dev eth1 table 200
    /app # ip route show table 200
    default via 172.18.0.1 dev eth1
    /app # ip rule show
    0:      from all lookup local 
    32765:  from 172.18.0.0/16 lookup 200 
    32766:  from all lookup main 
    32767:  from all lookup default
    

Now ask the kernel where a packet originating from our ``172.18.0.2``
address will get sent::

    /app # ip route get 10.10.10.10 from 172.18.0.2
    10.10.10.10 from 172.18.0.2 via 172.18.0.1 dev eth1


And finally, go back to the host and check to see if everything works
now::

    # curl --connect-timeout 5 192.168.121.98:5000 &>/dev/null && echo success || echo failure
    success
    # curl --connect-timeout 5 127.0.0.1:5000 &>/dev/null && echo success || echo failure
    success

Success!!

I don't know if source based routing can be incorporated into ``docker`` to fix this
problem or if there is a better solution. I guess we'll have to wait and find out.


| Enjoy!
|
| Dusty


**NOTE** I used the following versions of software for this blog post::

    # rpm -q docker docker-compose kernel-core
    docker-1.10.3-10.git8ecd47f.fc24.x86_64
    docker-compose-1.7.0-1.fc24.noarch
    kernel-core-4.5.4-300.fc24.x86_64
