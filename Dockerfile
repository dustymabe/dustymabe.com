FROM registry.fedoraproject.org/fedora:39 AS hugo

# Perform updates && Install rpms:
#     - rst2html (convert rst)
#     - git-core (for git hash)
#     - hugo (static web site generation)
#     - httpd (web server)
#     - findutils for /usr/bin/find
RUN dnf -y update
RUN dnf install -y /usr/bin/rst2html findutils git-core hugo

# Add in files and run hugo to generate static website
ADD . /context/
# podman doesn't recurse submodules
# https://github.com/containers/buildah/issues/3104
RUN test -f /context/hugo/themes/beautifulhugo/LICENSE || git -C /context/ submodule update --init
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
# allow rst2html to run. See https://gohugo.io/about/security-model/#security-policy
    export export HUGO_SECURITY_EXEC_ALLOW="^(rst2html|dart-sass-embedded|go|npx|postcss)$" && \
    hugo

FROM registry.fedoraproject.org/fedora:39

# Do update and install apache
RUN dnf -y update
RUN dnf install -y httpd mod_ssl openssl

# Fix permissions so that httpd can run in the restricted scc
RUN chgrp root /var/run/httpd && chmod g+rwx /var/run/httpd  && \
    chgrp root /var/log/httpd && chmod g+rwx /var/log/httpd
# In OpenShift we run as random uid and root group
# - Make /etc/httpd/conf{,.d} (root:root) group writable
# - Make *run* dirs group owned by root and group writable
RUN chmod g+w /etc/httpd/conf /etc/httpd/conf.d
RUN chown root:root /run/httpd /etc/httpd/run /run/httpd/htcacheclean
RUN chmod g+w /run/httpd /etc/httpd/run /run/httpd/htcacheclean

# Remove extraneous configs in conf.d and don't try to bind to port 80 or 443
RUN rm -f /etc/httpd/conf.d/[^ssl]*.conf && \
    sed -i 's/^Listen 80/Listen 8080/' /etc/httpd/conf/httpd.conf && \
    sed -i 's/443/8443/' /etc/httpd/conf.d/ssl.conf
#   sed -i 's/^Listen 443 https/Listen 8443 https/' /etc/httpd/conf.d/ssl.conf

EXPOSE 8080
EXPOSE 8443

CMD ["/usr/sbin/httpd", "-D", "FOREGROUND"]

# Copy static website files over to html directory to be served
COPY --from=hugo /context/hugo/public/ /var/www/html/
# Copy files in 'toplevel' dir to root of the html directory as well
COPY --from=hugo /context/toplevel/ /var/www/html/
# Make all files group owned by root for OpenShift
RUN chown -R apache:root /var/www/html/

# In openshift we run as random UID and root group. Try to simulate that here
USER 1001:0
