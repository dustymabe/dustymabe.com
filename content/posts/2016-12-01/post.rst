
.. Kompose Up for OpenShift and Kubernetes
.. =======================================

*Cross posted with this_ Red Hat Developer Blog post*

.. _this: http://developers.redhat.com/blog/2016/12/01/kompose-up-openshift-and-kubernetes/


Introduction
------------

Kompose_ is a tool to convert from higher level abstractions of
application definitions into more detailed Kubernetes artifacts.
These artifacts can then be used to bring up the application in a 
Kubernetes cluster. What higher level application abstraction should
kompose use?

One of the most popular application definition formats for developers is the 
``docker-compose.yml`` format for use with ``docker-compose``
that communicates with the docker daemon to bring up the application.
Since this format has gained some traction we decided to make it the
initial focus of Kompose to support converting this format to
Kubernetes. So, where you would choose ``docker-compose`` to bring up
the application in docker, you can use ``kompose`` to bring up the
same application in Kubernetes, if that is your preferred platform.

How Did We Get Here?
--------------------

At Red Hat, we had initially started on a project similar to Kompose,
called Henge_. We soon found Kompose and realized we had a lot of
overlap in our goals so we decided to jump on board with the folks
at `Skippbox`_ and Google who were already working on it.

.. _Kompose: https://github.com/kubernetes-incubator/kompose/
.. _Henge: https://github.com/redhat-developer/henge
.. _Skippbox: http://www.skippbox.com/

TL;DR We have been working hard with the Kompose and Kubernetes communities.
Kompose is `now a part of the Kuberetes Incubator`_ and we also have added 
support in Kompose for getting up and running into your target environment in
one command::

    $ kompose up 

.. _now a part of the Kuberetes Incubator: http://blog.kubernetes.io/2016/11/kompose-tool-go-from-docker-compose-to-kubernetes.html

In this blog I'll run you through a simple application example and use
``kompose up`` to bring up the application on Kuberenetes and OpenShift.

Getting an Environment
----------------------

It is now easier than ever to get up and running with Kubernetes and
Openshift. If you want hosted you can spin up clusters in many cloud
environments including `Google Container Engine`_ and `OpenShift Online`_
(with the developer preview). If you want a local experience for trying
out Kubernetes/OpenShift on your laptop, there is the RHEL based CDK_,
(and the ADB_ for upstream components), `oc cluster up`_, minikube_, and 
the list goes on!

.. _Google Container Engine: https://cloud.google.com/container-engine/
.. _OpenShift Online: https://www.openshift.com/devpreview/
.. _CDK: http://developers.redhat.com/products/cdk/overview/
.. _ADB: https://github.com/projectatomic/adb-atomic-developer-bundle
.. _oc cluster up: https://github.com/openshift/origin/blob/master/docs/cluster_up_down.md
.. _minikube: https://github.com/kubernetes/minikube

Any way you look at it, there are many options for trying out Kubernetes and
OpenShift these days. For this blog I'll choose to run on OpenShift Online, but
the steps should work on any Openshift or Kubernetes environment.

Once I had logged in to the openshift console at `api.preview.openshift.com`_ 
I was able to grab a token by visiting https://api.preview.openshift.com/oauth/token/request 
and clicking ``Request another token``. It then will show you the
``oc`` command you can run to log your local machine into openshift
online.

I'll log in below and create a new project for this example blog::

    $ oc login --token=xxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx --server=https://api.preview.openshift.com
    Logged into "https://api.preview.openshift.com:443" as "dustymabe" using the token provided.

    You don't have any projects. You can try to create a new project, by running

        $ oc new-project <projectname>

    $ oc new-project blogpost
    Now using project "blogpost" on server "https://api.preview.openshift.com:443".

    You can add applications to this project with the 'new-app' command. For example, try:

        $ oc new-app centos/ruby-22-centos7~https://github.com/openshift/ruby-hello-world.git

    to build a new hello-world application in Ruby.
    $

.. _api.preview.openshift.com: https://api.preview.openshift.com


Example Application
-------------------

Now that I have an environment to run my app in I need to give it an app to run!
I took the example ``mlbparks`` application that we have been using for
openshift for some time and converted the `template`_ to a more simplified
definition of the application using the ``docker-compose.yml`` format::

    $ cat docker-compose.yml
    version: "2"
    services:
      mongodb:
        image: centos/mongodb-26-centos7
        ports:
          - '27017'
        volumes:
          - /var/lib/mongodb/data
        environment:
          MONGODB_USER: user
          MONGODB_PASSWORD: mypass
          MONGODB_DATABASE: mydb
          MONGODB_ADMIN_PASSWORD: myrootpass
      mlbparks:
        image: dustymabe/mlbparks
        ports:
          - '8080'
        environment:
          MONGODB_USER: user
          MONGODB_PASSWORD: mypass
          MONGODB_DATABASE: mydb
          MONGODB_ADMIN_PASSWORD: myrootpass

.. _template: https://raw.githubusercontent.com/gshipley/openshift3mlbparks/master/mlbparks-template-wildfly.json

Basically we have the ``mongodb`` service and then the ``mlbparks`` service
which is backed by the ``dustymabe/mlbparks`` image. I simply generated this
image from the `openshift3mlbparks source code`_ using s2i_ with the following command::

    $ s2i build https://github.com/gshipley/openshift3mlbparks openshift/wildfly-100-centos7 dustymabe/mlbparks 

.. _openshift3mlbparks source code: https://github.com/gshipley/openshift3mlbparks
.. _s2i: https://github.com/openshift/source-to-image

Now that we have our compose yaml file we can use ``kompose`` to bring it up. I am
using kompose version `v0.1.2` here::


    $ kompose --version
    kompose version 0.1.2 (92ea047)
    $ kompose --provider openshift up
    We are going to create OpenShift DeploymentConfigs, Services and PersistentVolumeClaims for your Dockerized application. 
    If you need different kind of resources, use the 'kompose convert' and 'oc create -f' commands instead. 

    INFO[0000] Successfully created Service: mlbparks       
    INFO[0000] Successfully created Service: mongodb        
    INFO[0000] Successfully created DeploymentConfig: mlbparks 
    INFO[0000] Successfully created ImageStream: mlbparks   
    INFO[0000] Successfully created DeploymentConfig: mongodb 
    INFO[0000] Successfully created ImageStream: mongodb    
    INFO[0000] Successfully created PersistentVolumeClaim: mongodb-claim0 

    Your application has been deployed to OpenShift. You can run 'oc get dc,svc,is,pvc' for details.

.. _v0.1.2: https://github.com/kubernetes-incubator/kompose/releases/tag/v0.1.2

Ok what happened here... We created an ``mlbparks`` Service, DeploymentConfig
and ImageStream as well as a ``mongodb`` Service, DeploymentConfig, and ImageStream.
We also created a PersistentVolumeClaim named ``mongodb-claim0`` for the 
``/var/lib/mongodb/data``.

**Note**: If you don't have Persistent Volumes the application will never come
up because the claim will never get satisfied. If you want to deploy
somewhere without Persistent Volumes then add ``--emptyvols``
to your command like ``kompose --provider openshift up --emptyvols``.


So let's see what is going on in OpenShift by querying from the CLI::

    $ oc get dc,svc,is,pvc
    NAME             REVISION                               REPLICAS       TRIGGERED BY
    mlbparks         1                                      1              config,image(mlbparks:latest)
    mongodb          1                                      1              config,image(mongodb:latest)
    NAME             CLUSTER-IP                             EXTERNAL-IP    PORT(S)     AGE
    mlbparks         172.30.67.72                           <none>         8080/TCP    4m
    mongodb          172.30.111.51                          <none>         27017/TCP   4m
    NAME             DOCKER REPO                            TAGS           UPDATED
    mlbparks         172.30.47.227:5000/blogpost/mlbparks   latest         4 minutes ago
    mongodb          172.30.47.227:5000/blogpost/mongodb    latest         4 minutes ago
    NAME             STATUS                                 VOLUME         CAPACITY   ACCESSMODES   AGE
    mongodb-claim0   Bound                                  pv-aws-adbb5   100Mi      RWO           4m

and the web console looks like:

.. image:: http://dustymabe.com/content/2016-12-01/openshift.png
   :align: center 

One final thing we have to do is set it up so that we can connect to the service (i.e.
the service is exposed to the outside world). On OpenShift, we need to expose a route.
This will be done for us automatically in the future (follow along at `#140`_), but for
now the following command will suffice::

    $ oc expose svc/mlbparks
    route "mlbparks" exposed
    $ oc get route mlbparks 
    NAME       HOST/PORT                                          PATH      SERVICE         TERMINATION   LABELS
    mlbparks   mlbparks-blogpost.44fs.preview.openshiftapps.com             mlbparks:8080                 service=mlbparks

.. _#140: https://github.com/kubernetes-incubator/kompose/issues/140

For me this means I can now access the mlbparks application by pointing my 
web browser to ``mlbparks-blogpost.44fs.preview.openshiftapps.com``. 

Let's try it out:

.. image:: http://dustymabe.com/content/2016-12-01/mlbparks.png
   :align: center 

| Success!
| Dusty
