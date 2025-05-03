---
title: "Archived-At Email Header From Mailman 3 Lists"
tags:
date: "2016-01-10"
draft: false
---

.. Archived-At Email Header From Mailman 3 Lists
.. =============================================


By now most Fedora email lists have been migrated_ to Mailman3_. One
little (but killer) new feature that I recently discovered was that
Mailman3 includes the `RFC 5064`_ **Archived-At** header in the emails.

.. _migrated: http://fedoraproject.org/wiki/Mailman3_Migration
.. _Mailman3: http://wiki.list.org/DEV/Mailman%203.0
.. _RFC 5064: http://tools.ietf.org/html/rfc5064

This is a feature I have wanted for a really long time; to be able to
find an email in your Inbox and copy and paste a link to anyone
without having to find the message in the online archive is going to
save a lot of time and decrease some latency when chatting on IRC or
some other form of real time communication.

OK, how do I easily get this information out of the header and use
it without having to view the email source every time? 

I use Thunderbird for most of my email viewing (sometimes mutt for
composing). In Thunderbird there is the **Archived-At** plugin_. After
installing this plugin you can right click on any message from a
capable mailing list and select *"Copy Archived-At URL"*. 

.. _plugin: https://addons.mozilla.org/en-us/thunderbird/addon/archived-at/?src=search

Now you are off to share that URL with friends :)

| Happy New Year!
| Dusty
