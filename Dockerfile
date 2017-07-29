#FROM       registry.fedoraproject.org/fedora:rawhide
FROM       registry.fedoraproject.org/f25/httpd

USER root

# Install httpd and rst2html
RUN dnf install -y httpd /usr/bin/rst2html && dnf clean all

# Install hugo from copr
RUN curl -L https://copr.fedorainfracloud.org/coprs/dustymabe/hugo/repo/fedora-rawhide/dustymabe-hugo-fedora-rawhide.repo > /etc/yum.repos.d/dustymabe-hugo-fedora-rawhide.repo
#RUN dnf install --releasever 27 -y hugo && dnf clean all
RUN dnf install -y hugo && dnf clean all

# Add in files and run hugo to generate static website
ADD . /context/
RUN cd /context/hugo && hugo || true

# Copy static website files over to html directory to be served
#RUN cp -R /context/hugo/public/* /var/www/html/
#RUN chown -R apache:apache /var/www/html/

#RUN sed -i 's/Listen 80/Listen 8080/' /etc/httpd/conf/httpd.conf

#VOLUME /var/www/html/

USER 1001
#EXPOSE 80

LABEL io.openshift.expose-services 8080/tcp

#CMD cp httpd -DFOREGROUND
CMD mkdir -p /var/www/html/ && cp -R /context/hugo/public/* /var/www/html/ && /usr/bin/run-httpd
