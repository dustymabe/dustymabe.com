FROM       registry.fedoraproject.org/f25/httpd

USER root

# Install rst2html (convert rst) and git (for git hash)
RUN dnf install -y git /usr/bin/rst2html && dnf clean all

# Install hugo from copr
RUN curl -L https://copr.fedorainfracloud.org/coprs/dustymabe/hugo/repo/fedora-rawhide/dustymabe-hugo-fedora-rawhide.repo > /etc/yum.repos.d/dustymabe-hugo-fedora-rawhide.repo
RUN dnf install -y hugo && dnf clean all

# Add in files and run hugo to generate static website
ADD . /context/
RUN cd /context/hugo && \
    export GIT_COMMIT_SHA=$(git rev-parse --verify HEAD)      && \
    export GIT_COMMIT_SHA_SHORT=$(git rev-parse --short HEAD) && \
    hugo || true

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
