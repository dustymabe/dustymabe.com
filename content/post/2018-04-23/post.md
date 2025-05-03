---
title: "April Fedora Infrastructure Hackfest"
tags: [ fedora, atomic ]
date: "2018-04-23"
draft: false
---


# Introduction

Earlier this month I was lucky enough to attend the 
[2018 Fedora Infrastructure Hackfest](https://fedoraproject.org/wiki/Infrastructure_Hackathon_2018).
It's always a treat to hang out with some of the people who really
make Fedora tick.
[Sinny Kumari](https://twitter.com/ksinny)
and I were there to help represent the
[Atomic Working Group](https://fedoraproject.org/wiki/Atomic_WG),
and also get some face time with each other to learn and hack on a
few things related to the Atomic Working group.

The Hackfest was held in
[Paul Frield's](https://twitter.com/stickster)
hometown of Fredricksburg, VA.
Since I live in Raleigh, NC I decided it would be nice to take the
train since I don't often get to take the train in the southeast. As
can be expected the train was a little late, but got us there without
a problem and was a pretty good experience. 

# Hacking

Once we got the Hackfest started we dug into quite a few topics. Here
are the ones I was most involved in:

- Fedora OpenShift, making it easier for Infrastructure Developers

The way the Fedora OpenShift instance is set up is a bit rigid for the
developers. OpenShift has a lot of tools that make it really easy to
get started in an OpenShift environment but those tools have a certain
level of *magic* that make it hard as an admin to reproduce when
trying to re-deploy an app in a DR scenario. We discussed options for
making it easier for developers to deploy and manage their apps in
OpenShift as well as the option for having apps with low SLEs be able
to be fully managed by the developer. The result of this discussion
is TBD.

- Gating in Rawhide

This was a topic of discussion all week and many different
possibilities came of it. In short we really want to gate rawhide so
the state of rawhide isn't always broken. We want to make it easier
for maintainers to build things in side-tags (by making them
self-service I believe) and verify things are broken before getting
them into rawhide. As always, the more automated testing we have
around this the better off we'll be.

- Ostree Mirroring

We've wanted proper 
[OSTree mirroring support](https://pagure.io/fedora-infrastructure/issue/5970)
for a while, but there
have always been other fires to fight. This is true for both the
Atomic side as well as the Fedora Infra side. Recently I proposed
an intermediary solution which is to use a CDN (thanks to 
[@davdunc](https://twitter.com/davdunc) and Amazon for letting us
use Cloudfront for this).
[@puiterwijkFP](https://twitter.com/puiterwijkFP)
and I set up
[http://dl.fedoraproject.org/atomic/repo/](http://dl.fedoraproject.org/atomic/repo/)
as a repo
fronted by Cloudfront. The
[/objects/ directory](http://dl.fedoraproject.org/atomic/repo/objects/)
is fronted by Cloudfront, but everything else (the parts that can
change are served by Fedora. Hopfeully this will help us serve users
in non US locales better.

- Building Atomic Host Artifacts during Bodhi Pungi Runs

In the past we've built OSTree commits during Bodhi runs and then
later generated ISOs, Qcows, and Vagrant Boxes in a separate run.
We've wanted to combine these for a while for a few reasons; one is
that we don't want to guess which commit ended up in which artifact
Pungi run, and another is that we want the version numbers of
the OSTree to match the version numbers in the media ISO or Qcow
names. Combining it all into a single run means we can do that.

I sat down with [@puiterwijkFP](https://twitter.com/puiterwijkFP) and we
[hammered out a prototype](https://infrastructure.fedoraproject.org/cgit/ansible.git/commit/?id=2c3b643da2af0313707df0857a49a1c91969a3ad)
during the Hackfest. We've been tweaking it since to get things right,
but this was a big step forward.

- Displaying multi-arch Atomic Host Artifacts on getfedora.org

In Fedora 27 we started releasing multi-arch content for Fedora
Atomic Host. Wooo!! The only 
[problem](https://pagure.io/atomic-wg/issue/389)
is that we haven't yet got
around to updating the website to display the content so that new
users could *discover* it. 

During the Hackfest [Sinny]()
and I sat down with [@ryanlerch](https://twitter.com/ryanlerch) and
sketched out a design for what we thing this could look like. This
work along with the 
[fedmsg update for multi-arch content](https://pagure.io/atomic-wg/issue/392)
should enable us to get the multi-arch content on the website every 
time we do a new release.

- Knowledge Transfer of Two Week Atomic Processes

Sinny has been helping me out recently with some of the processes
surrounding the Fedora Atomic Host two week releases. She has been
an excellent help so far and has mastered everything I've asked her
to do. Since we are approaching Fedora 28 we decided to sit down
together and discuss what things need to be done when we switch from
Fedora 27 to Fedora 28 for Atomic Host. This involves coordinating
with releng on several tasks and also with the websites team.

- Discussion about rojig

I mentioned before OSTree mirroring. There is an effort from the
rpm-ostree core team to support delivering OSTree commits via rpms.
This effort is known as 
[rojig](https://github.com/projectatomic/rpm-ostree/issues/1081).
As the content would be delivered
via rpms we could leverage the existing mirror network that Fedora
has in order to deliver updates. The only problem with this approach
is that browsing the commit history (by deploying older commits)
requires that old rpms exist in the yum repos as well, which is not
something Fedora has done up until this point.

# Fin

Overall the hackfest was a great experience. We got a lot done, but
even more so we got some face time with people that we often just
interact with through zeroes and ones. I think this face time is
actually more important than the work we accomplish during the
hackfest. Building these relationships is really important and
actually helps the team be more efficient because our communication
barriers are eased by the development of stronger relationships.

Thanks to everyone who was there for making this trip an awesome
experience! Until next time..

