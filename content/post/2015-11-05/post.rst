---
title: "Getting Ansible Working on Fedora 23"
tags:
date: "2015-11-05"
published: true
---

.. Getting Ansible Working on Fedora 23
.. ====================================

*Cross posted with this_ fedora magazine post*

*Inspired mostly from a post_ by Lars Kellogg-Stedman.*

.. _this: https://fedoramagazine.org/getting-ansible-working-fedora-23/
.. _post: http://blog.oddbit.com/2015/10/15/bootstrapping-ansible-on-fedora-23/


Intro
-----

Ansible_ is a simple IT automation platform written in python that makes your
applications and systems easier to deploy. It has become quite popular
over the past few years but you may hit some trouble when trying to
run Ansible on Fedora 23.  

Fedora 23 is using python 3 as the default python version that gets
installed (see changes_), but Ansible still requires python 2. For 
that reason Ansible errors out when you try to run it because it assumes 
python 2 by default::

    GATHERING FACTS *
    failed: [f23] => {"failed": true, "parsed": false}
    /bin/sh: /usr/bin/python: No such file or directory

.. _Ansible: http://www.ansible.com/
.. _changes: https://fedoraproject.org/wiki/Changes/Python_3_as_Default

Fortunately there are a few steps you can add to your playbooks in
order to fully workaround this problem. You can either choose to apply
them in a single play or in mulitple plays as shown below.

Workaround - Single All-in-One Play
-----------------------------------

In the case of a single play, which is something I use often when
applying configuration to vagrant boxes, you can workaround this
problem by taking the following steps:

- Explicitly disable the gathering of facts on initialization
- Use Ansible's raw module to install python2
- Explicitly call the setup module to gather facts again

The gathering of facts that happens by default on ansible execution
will try to use python 2. We must disable this or it will fail before
executing the raw_ ssh commands to install python 2. Fortunately we can
still use facts in our single play, though, by explicitly calling the
setup_ module after python2 is installed.

.. _raw: http://docs.ansible.com/ansible/raw_module.html
.. _setup: http://docs.ansible.com/ansible/setup_module.html

So with these minor changes applied a simple all in one play might look
like::

    - hosts: f23
      remote_user: fedora
      gather_facts: false
      become_user: root
      become: yes
      tasks:
        - name: install python and deps for ansible modules
          raw: dnf install -y python2 python2-dnf libselinux-python
        - name: gather facts
          setup:
        - name: use facts
          lineinfile: dest=/etc/some-cfg-file line="myip={{ ansible_eth0.ipv4.address }}" create=true


And the output of running the play should be successful::

    PLAY [f23] **************************************************************** 

    TASK: [install python and deps for ansible modules] *************************** 
    ok: [f23]

    TASK: [gather facts] ********************************************************** 
    ok: [f23]

    TASK: [use facts] ************************************************************* 
    changed: [f23]

    PLAY RECAP ******************************************************************** 
    f23                        : ok=3    changed=1    unreachable=0    failed=0


Workaround - Multiple Plays
---------------------------

If you use multiple plays in your playbooks then you can simply have
one of them do the python 2 install in raw_ mode while the others can
remain unchanged; you don't have to explicitly gather facts because
python 2 is now installed. So for the first play you would have
something like::

    - hosts: f23
      remote_user: fedora
      gather_facts: false
      become_user: root
      become: yes
      tasks:
        - name: install python and deps for ansible modules
          raw: dnf install -y python2 python2-dnf libselinux-python

And, re-using the code from the sample above the second play would
look like::

    - hosts: f23
      remote_user: fedora
      become_user: root
      become: yes
      tasks:
        - name: use facts
          lineinfile: dest=/etc/some-cfg-file line="myip={{ ansible_eth0.ipv4.address }}" create=true


Conclusion
----------

So using these small changes you should be back up and running until Ansible adds
first class support for python 3.

| Enjoy!
| Dusty
