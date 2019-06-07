FROM registry.fedoraproject.org/f29/httpd

USER root

# Perform updates && Install rpms:
#     - rst2html (convert rst)
#     - git (for git hash)
#     - hugo (static web site generation)
RUN dnf -y update && dnf install -y /usr/bin/rst2html git hugo && dnf clean all

# Generate SSL certs
# https://bugzilla.redhat.com/show_bug.cgi?id=1585533
RUN /usr/libexec/httpd-ssl-gencerts
RUN chmod 644 /etc/pki/tls/private/localhost.key

# Add in files and run hugo to generate static website
ADD . /context/
RUN cd /context/hugo && \
# Use git ls-remote for now to determine SHA. This is because
# Openshift doesn't properly copy over .git directory for now
# See https://trello.com/c/C1gwxci3/856-3-include-git-repository-during-build-builds
    export GIT_COMMIT_SHA=$(git ls-remote https://github.com/dustymabe/dustymabe.com.git master | cut -f 1) && \
    export GIT_COMMIT_SHA_SHORT=${GIT_COMMIT_SHA:0:7} && \
#   export GIT_COMMIT_SHA=$(git rev-parse --verify HEAD)      && \
#   export GIT_COMMIT_SHA_SHORT=$(git rev-parse --short HEAD) && \
    hugo || true


# In OpenShift we run as random uid and root group
# Make /etc/httpd/conf{,.d} (root:root) group writable
RUN chmod g+w /etc/httpd/conf
RUN chmod g+w /etc/httpd/conf.d

# Copy static website files over to html directory to be served
# Make all files group owned by root for OpenShift
RUN cp -R /context/hugo/public/* /var/www/html/
RUN chown -R apache:root /var/www/html/

#RUN sed -i 's/Listen 80/Listen 8080/' /etc/httpd/conf/httpd.conf

#VOLUME /var/www/html/

USER 1001
#EXPOSE 80

#CMD cp httpd -DFOREGROUND
#CMD mkdir -p /var/www/html/ && cp -R /context/hugo/public/* /var/www/html/ && /usr/bin/run-httpd
CMD /usr/bin/run-httpd
