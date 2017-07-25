# Wordpress
#
# VERSION               0.0.1

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
