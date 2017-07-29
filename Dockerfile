FROM       registry.fedoraproject.org/fedora:rawhide

# Install httpd and rst2html
RUN dnf install -y httpd /usr/bin/rst2html && dnf clean all

# Install hugo from copr
RUN curl -L https://copr.fedorainfracloud.org/coprs/dustymabe/hugo/repo/fedora-rawhide/dustymabe-hugo-fedora-rawhide.repo > /etc/yum.repos.d/dustymabe-hugo-fedora-rawhide.repo
RUN dnf install --releasever 27 -y hugo && dnf clean all

# Add in files and run hugo to generate static website
ADD . /context/
RUN cd /context/hugo && hugo || true

# Copy static website files over to html directory to be served
RUN cp -R /context/hugo/public/* /var/www/html/
RUN chown -R apache:apache /var/www/html/

#RUN sed -i 's/Listen 80/Listen 8080/' /etc/httpd/conf/httpd.conf

#USER apache
EXPOSE 80

CMD httpd -DFOREGROUND
