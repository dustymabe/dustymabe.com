---
title: "The CentOS CI Infrastructure: A Getting Started Guide"
tags:
date: "2016-01-23"
published: true
---

.. The CentOS CI Infrastructure: A Getting Started Guide
.. =====================================================

Background
----------

The CentOS_ community is trying to build an ecosystem that fosters and 
encourages upstream communities to continuously perform integration 
testing of their code running on the the CentOS platform. The CentOS
community has built out an infrastructure that (currently) contains 
256 servers_ (*"bare metal"* servers") that are pooled together to run
tests that are orchestrated by a frontend Jenkins instance located at
`ci.centos.org`_.

.. _servers: https://wiki.centos.org/QaWiki/PubHardware
.. _CentOS: https://www.centos.org/
.. _ci.centos.org: https://ci.centos.org/

Who Can Use the CentOS CI?
--------------------------

The CentOS CI is primarily targeted at Open Source projects that use
CentOS as a platform in some way. If your project meets those two
requirements then check out our page for `Getting Started`_ and look
at the **"Asking for your project to be added"** section.

.. _Getting Started: https://wiki.centos.org/QaWiki/CI/GettingStarted

What Is Unique About the CentOS CI?
-----------------------------------

With many test infrastructures that exist today you are given a
virtual machine. With the CentOS CI, when you get a test machine you are
actually getting a *"bare metal"* machine, which allows for testing of 
workloads that may have not been possible otherwise. One specific
example of this is testing out virtualization workloads. The RDO_ and
libvirt_ projects both use the CentOS CI to do testing that wouldn't
be possible on an infrastructure that didn't provide bare metal.

.. _RDO: https://www.rdoproject.org/
.. _libvirt: http://libvirt.org/

The CentOS CI also offers early access to content that will be in a coming
release of CentOS. If there is a pending release, then the content will be
available for testing in the CI infrastructure. This allows projects to do
testing and find bugs early (before release).

I Have Access. Now What?
------------------------

Credentials/Environment
=======================

Now that you have access to the CentOS CI you should have a few
things:

    - Username/Password for the `ci.centos.org`_ Jenkins frontend
    - An API key to use with Duffy
    - A target slave type to be used for your testing

The 2nd item from above is unique. In order to provision
the bare metal machines and present them for testing, the CentOS CI
uses a service known as Duffy_ (a REST API). The Jenkins jobs that
run must provision machines using Duffy and then execute tests on
those machines; in the future there may be a Jenkins plugin that
takes care of this for you.

.. _Duffy: https://wiki.centos.org/QaWiki/CI/Duffy

The 3rd item is actually specific to your project. The slave machines
that are contacted from Jenkins have a workspace set up (like a home
directory) for your project. These slaves are accessible via SSH and
you can put whatever files you need here in order to orchestrate your
tests. When a command is executed in a Jenkins job, these machines are
the ones that it is run on.

What you really want, however, is to run tests on the Duffy instances.
For that reason the slave is typically just used to request an
instance from Duffy and then ssh into the instance to execute tests.

A Test To Run
=============

Even though we've brought the infrastructure together we still need
you to write the tests! Basically the requirement here is that you
have a git repo that can be cloned on the Duffy instance and then a
command to run to kick off the tests. 

A very simple example of this is my `centos-ci-example`_ repo on GitHub. In
this repo the run_tests.sh script executes tests. So for our case
we will use the following environment varialbes when defining our
Jenkins job below::

    GIT_REPO_URL=https://github.com/dustymabe/centos-ci-example
    TEST_CMD='./run_tests.sh'


.. _centos-ci-example: https://github.com/dustymabe/centos-ci-example


Your First Job: Web Interface
=============================

So you have access and you have a git repo that contains a test to run.
With the username/password you can login to `ci.centos.org`_ and create
a new job. To create a new job select **New Item** from the menu on
the left hand side of the screen. Enter a name for your job and
**Freestyle Project** as shown below:

.. image:: http://dustymabe.com/content/2016-01-23/ci-new-job.png
   :align: center

After clicking OK, the next page that appears is the page for
configuring your job. The following items need to be filled in:

- Check **Restrict where this project can be run**
    - Enter the label that applies to environment set up for you 

As you can see below, for me this was the ``atomicapp-shared`` label.

.. image:: http://dustymabe.com/content/2016-01-23/ci-restrict-nodes.png
   :align: center

- Check **Inject environment variables to the build process** under **Build Environment**
    - Populate the environment variables as shown below:

.. image:: http://dustymabe.com/content/2016-01-23/ci-env-vars.png
   :align: center

- Click on the **Add Build Step** Dropdown and Select **Execute Python Script**

.. image:: http://dustymabe.com/content/2016-01-23/ci-exec-python.png
   :align: center

- Populate a python script in the text box
    - This script will be executed on the jenkins slaves
    - It will provision new machines using Duffy and then execute the test(s).
    - This script can be found on GitHub_ or here_

.. _GitHub: https://github.com/dustymabe/centos-ci-example/blob/master/jjb/run.py
.. _here: http://dustymabe.com/content/2016-01-23/run.py

.. image:: http://dustymabe.com/content/2016-01-23/ci-python-script.png
   :align: center

Now you are all done configuring your job for the first time. There are plenty of more 
options that Jenkins gives you, but for now click **Save** and then run the job. You
can do this by clicking **Build Now** and then viwing the output by selecting 
**Console Output** as shown in the screenshot below:

.. image:: http://dustymabe.com/content/2016-01-23/ci-build-now.png
   :align: center

Your Next Job: Jenkins Job Builder
==================================

All of those steps can be done in a more *automated* fashion by using 
`Jenkins Job Builder`_. You must install the ``jenkins-jobs`` executable
for this and create a config file that holds the credentials to interface
with Jenkins::

    # yum install -y /usr/bin/jenkins-jobs
    # cat <<EOF > jenkins_jobs.ini
    [jenkins]
    user=username
    password=password
    url=https://ci.centos.org
    EOF

.. _Jenkins Job Builder: http://docs.openstack.org/infra/jenkins-job-builder/

Update the file to have the real user/password in it. 

Next you must create a job description::

    # cat <<EOF >job.yaml
    - job:
        name: dusty-ci-example
        node: atomicapp-shared
        builders:
            - inject:
                properties-content: |
                    API_KEY=aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee
                    MACHINE_COUNT=1
                    TEST_CMD='./run_tests.sh'
                    GIT_REPO_URL='https://github.com/dustymabe/centos-ci-example.git'
            - centos-ci-bootstrap
    - builder:
        name: centos-ci-bootstrap
        builders:
            - python:
                !include-raw: './run.py'
    EOF

Update the file to have the real API_KEY.

The last component is ``run.py``, which is the python script we pasted in before::

    # curl http://dustymabe.com/content/2016-01-23/run.py > run.py


Now you can run ``jenkins-jobs`` and update the job::

    # jenkins-jobs --conf jenkins_jobs.ini update job.yaml
    INFO:root:Updating jobs in ['job.yaml'] ([])
    INFO:jenkins_jobs.local_yaml:Including file './run.py' from path '.'
    INFO:jenkins_jobs.builder:Number of jobs generated:  1
    INFO:jenkins_jobs.builder:Reconfiguring jenkins job dusty-ci-example
    INFO:root:Number of jobs updated: 1
    INFO:jenkins_jobs.builder:Cache saved


**NOTE:** This is all reproduced in the centos-ci-example `jjb directory`_.
Cloning the repo and executing the files from there may be a little easier
than running the commands above.

.. _jjb directory: https://github.com/dustymabe/centos-ci-example/tree/master/jjb

After executing all of the steps you should now be able to execute **Build Now** on the job, 
just as before. Take `Jenkins Job Builder`_ for a spin and consider it a useful tool when
managing your Jenkins jobs.


Conclusion
----------

Hopefully by now you can set up and execute a basic test on the CentOS CI. Come and
join our community and help us build out the infrastructure and the feature set. Check
out the `CI Wiki`_, send us a mail on the ci-users@centos.org mailing list or ping us 
on #centos-devel in Freenode.

.. _CI Wiki: https://wiki.centos.org/QaWiki/CI

| Happy Testing!
| Dusty
