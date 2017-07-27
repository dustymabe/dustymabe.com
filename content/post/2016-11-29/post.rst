---
title: "Fedora 25 available in DigitalOcean"
tags:
date: "2016-11-29"
published: true
---

.. Fedora 25 available in DigitalOcean
.. ===================================

*Cross posted with this_ fedora magazine post*

.. _this: https://fedoramagazine.org/fedora-25-available-digitalocean/

Last week the Fedora Project `released Fedora 25`_. This week Fedora
Project Community members have worked with the 
DigitalOcean team to make Fedora 25 `available on their platform`_.
If you're not familiar with DigitalOcean already, it's a dead simple 
cloud hosting platform that's great for developers.

.. _released Fedora 25: https://fedoramagazine.org/fedora-25-released/
.. _available on their platform: https://www.digitalocean.com/

Important Notes
---------------

The image has some specific differences from others that Fedora ships.
You may need to know about these differences before you use the image.

- Usually Fedora Cloud images have you log in as user *fedora*. But as with other
  DigitalOcean images, **log into the Fedora 25 DigitalOcean cloud image with your 
  ssh key as root**.
- Similar to our last few Fedora releases, Fedora 25 also has 
  **SELinux enabled by default**. Not familiar with SELinux yet? No
  problem. `Read more about it here`_
- In these images there's **no firewall on by default**. There's also 
  **no cloud provided firewall solution**. We recommend that you secure
  your system immediately after you log in.
- Fedora 25 should be **available in all datacenters** across the globe.
- If you have a
  problem you think is **Fedora specific** then drop us an email at
  cloud@lists.fedoraproject.org, or ping us in `#fedora-cloud`_ on Freenode.
  You can also let the team know if you just want to say you're
  enjoying using the F25 image.

.. _Read more about it here: https://fedoraproject.org/wiki/SELinux
.. _#fedora-cloud: https://webchat.freenode.net/?channels=#fedora-cloud

Visit the DigitalOcean `Fedora landing page`_ and spin one up today!

.. _Fedora landing page: https://www.digitalocean.com/features/linux-distribution/fedora/


| Happy Developing!
| Dusty
