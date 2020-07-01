FROM registry.fedoraproject.org/fedora:32

# Perform updates && Install rpms:
#     - rst2html (convert rst)
#     - git (for git hash)
#     - hugo (static web site generation)
#     - httpd (web server)
RUN dnf -y update && dnf install -y httpd /usr/bin/rst2html git hugo && dnf clean all


#### APACHE STUFF #########

# Fix permissions so that httpd can run in the restricted scc
RUN chgrp root /var/run/httpd && chmod g+rwx /var/run/httpd  && \
    chgrp root /var/log/httpd && chmod g+rwx /var/log/httpd
# In OpenShift we run as random uid and root group
# - Make /etc/httpd/conf{,.d} (root:root) group writable
# - Make *run* dirs group owned by root and group writable
RUN chmod g+w /etc/httpd/conf /etc/httpd/conf.d
RUN chown root:root /run/httpd /etc/httpd/run /run/httpd/htcacheclean
RUN chmod g+w /run/httpd /etc/httpd/run /run/httpd/htcacheclean

# Remove any existing configs in conf.d and don't try to bind to port 80
RUN rm -f /etc/httpd/conf.d/* && \
    sed -i 's/^Listen 80/Listen 8080/' /etc/httpd/conf/httpd.conf

EXPOSE 8080

CMD ["/usr/sbin/httpd", "-D", "FOREGROUND"]


#### HUGO STUFF #########

# Add in files and run hugo to generate static website
ADD . /context/
RUN cd /context/hugo && \
# hugo no longer allows the static dir to be a symlink so let's
# copy the content over:
    rm /context/hugo/static && mkdir /context/hugo/static && \
    cp -R /context/content/post/* /context/hugo/static/ && \
# remove "empty" files that are there so we can have empty dirs
# in git.
    find . -name empty -delete && \
# Use git ls-remote for now to determine SHA. This is because
# Openshift doesn't properly copy over .git directory for now
# See https://trello.com/c/C1gwxci3/856-3-include-git-repository-during-build-builds
    export GIT_COMMIT_SHA=$(git ls-remote https://github.com/dustymabe/dustymabe.com.git master | cut -f 1) && \
    export GIT_COMMIT_SHA_SHORT=${GIT_COMMIT_SHA:0:7} && \
#   export GIT_COMMIT_SHA=$(git rev-parse --verify HEAD)      && \
#   export GIT_COMMIT_SHA_SHORT=$(git rev-parse --short HEAD) && \
    hugo



# Copy static website files over to html directory to be served
RUN cp -R /context/hugo/public/* /var/www/html/
# Copy files in 'toplevel' dir to root of the html directory as well
RUN cp -R /context/toplevel/* /var/www/html/
# Make all files group owned by root for OpenShift
RUN chown -R apache:root /var/www/html/

# In openshift we run as random UID and root group. Try to simulate that here
USER 1001:0
