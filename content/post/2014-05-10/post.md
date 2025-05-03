---
title: "Zero to Wordpress on Docker in 5 Minutes"
tags:
date: "2014-05-10"
draft: false
---

#### *Introduction*

\
[Docker](https://www.docker.io/) is an emerging technology that has
garnered a lot of momentum in the past year. I have been busy with a
move to NYC and a job change (now officially a Red Hatter), so I am just
now getting around to getting my feet wet with Docker.\
\
Last night I sat down and decided to bang out some steps for installing
wordpress in a docker container. Eventually I plan to move this site
into a container so I figured this would be a good first step.

#### *DockerPress*

\
There a few bits and pieces that need to be done to configure wordpress.
For simplicity I decided to make this wordpress instance use `sqlite`
rather than `mysql`. Considering all of this here is the basic recipe
for wordpress:\

-   Install `apache` and `php.`
-   Download [wordpress](http://www.wordpress.org/download) and extract
    to appropriate folder.
-   Download the
    [sqlite-integration](http://wordpress.org/plugins/sqlite-integration/installation/)
    plugin and extract.
-   Modify a few files...and DONE.

This is easily automated by creating a Dockerfile and using docker. The
minimal Dockerfile (with comments) is shown below:\

```nohighlight
FROM       goldmann/f20
MAINTAINER Dusty Mabe <dustymabe@gmail.com>

# Install httpd and update openssl
RUN yum install -y httpd openssl unzip php php-pdo

# Download and extract wordpress
RUN curl -o wordpress.tar.gz http://wordpress.org/latest.tar.gz
RUN tar -xzvf wordpress.tar.gz --strip-components=1 --directory /var/www/html/
RUN rm wordpress.tar.gz

# Download plugin to allow WP to use sqlite
# http://wordpress.org/plugins/sqlite-integration/installation/
#     - Move sqlite-integration folder to wordpress/wp-content/plugins folder.
#     - Copy db.php file in sqlite-integratin folder to wordpress/wp-content folder.
#     - Rename wordpress/wp-config-sample.php to wordpress/wp-config.php.
#
RUN curl -o sqlite-plugin.zip http://downloads.wordpress.org/plugin/sqlite-integration.1.6.3.zip
RUN unzip sqlite-plugin.zip -d /var/www/html/wp-content/plugins/
RUN rm sqlite-plugin.zip
RUN cp /var/www/html/wp-content/{plugins/sqlite-integration/db.php,}
RUN cp /var/www/html/{wp-config-sample.php,wp-config.php}

#
# Fix permissions on all of the files
RUN chown -R apache /var/www/html/
RUN chgrp -R apache /var/www/html/

#
# Update keys/salts in wp-config for security
RUN                                     \
    RE='put your unique phrase here';   \
    for i in {1..8}; do                 \
        KEY=$(openssl rand -base64 40); \
        sed -i "0,/$RE/s|$RE|$KEY|" /var/www/html/wp-config.php;  \
    done;                      

#
# Expose port 80 and set httpd as our entrypoint
EXPOSE 80
ENTRYPOINT ["/usr/sbin/httpd"]
CMD ["-D", "FOREGROUND"]
```

\
With the power of the Dockerfile you can now build a new image using
`docker build` and then run the new container with the `docker run`
command. An example of these two commands is shown below:\

```nohighlight
[root@localhost ~]# ls Dockerfile
Dockerfile
[root@localhost ~]# docker build -t "wordpress" .
...
Successfully built 0b388013905e
...
[root@localhost ~]#
[root@localhost ~]# docker run  -d -p 8080:80 -t wordpress
6da59c864d35bb0bb6043c09eb8b1128b2c1cb91f7fa456156df4a0a22f271b0
```

\
The `docker build` command will build an image from the Dockerfile and
then tag the new image with the "wordpress" tag. The `docker run`
command will run a new container based on the "wordpress" image and bind
port 8080 from the host machine to port 80 within the container.\
\
Now you can happily point your browser to http://localhost:8080 and see
the wordpress 5 minute installation screen:\
\
<img src="/2014-05-10/wp-install.jpeg" style="vertical-align:middle" height="285" width="400" />
\
See a full screencast of the "zero to wordpress" process using docker
[here](/2014-05-10/screencast.html) .\
Download the Dockerfile [here](/2014-05-10/Dockerfile) .\
\
Cheers!\
Dusty\
\
**NOTE:** This was done on Fedora 20 with
docker-io-0.9.1-1.fc20.x86\_64.
