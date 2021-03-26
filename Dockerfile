FROM registry.fedoraproject.org/fedora:33
ADD . /context/
RUN test -f /context/hugo/themes/beautifulhugo/LICENSE
