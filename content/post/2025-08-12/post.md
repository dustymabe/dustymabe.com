---
title: "PoC: Leveraging Butane during Ignition boot"
tags: [ coreos ignition butane ]
date: "2025-08-12"
draft: false
---

# Converting Butane to Ignition on Boot

We've received anecdotal evidence over the years that the
transpilation step where you must convert a Butane YAML configuration
into Ignition JSON before staring your CoreOS instance is a pain
for users to understand and implement. CoreOS developers also feel
this pain at times. 

What if you could feed either a Butane YAML config or an Ignition JSON
config to your instance and it would just do the right thing
regardless?

I did a proof of concept of this and showed a short demo during an
internal team meeting last week. Check it out (below) and let us know what
you think over in https://github.com/coreos/fedora-coreos-tracker/issues/2006

<video controls width="480" height="270" src="https://dustymabecom.sfo2.digitaloceanspaces.com/2025-08-12_PoC-Leveraging-Butane-During-Ignition-Boot.mp4"></video>

