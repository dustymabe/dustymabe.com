---
title: 'The K9s TUI for Kubernetes'
author: dustymabe
date: 2020-07-18
tags: [ kubernetes, openshift, okd ]
published: true
---

If you've ever had a chance to _"nerd out"_ with me much I've probably
told you about at least one TUI that I use to make my daily work life
easier. Some of my favorites include
[htop](https://github.com/hishamhm/htop),
[tig](https://github.com/jonas/tig),
[tmux](https://github.com/tmux/tmux) (not sure if tmux counts), etc..

Lately I've been finding myself using Kubernetes/OpenShift much more
and I have often thought to myself I wish a nice TUI existed to get
in and navigate resources in a Kubernetes environment. The various
web interfaces are nice and comprehensive, and the CLI is awesome too,
but each of them are too far on the fringes of what I'll define as
my sweet spot for discoverability vs speed vs power. A well designed
TUI sits right in the middle and makes me feel right at home.

Enter [K9s](https://github.com/derailed/k9s), described as providing
_"a terminal UI to interact with your Kubernetes clusters"_. This is
precisely the tool I've been looking for. The primary interface for
the tool is using `:` and typing in the name of an object type (like
`deployments`). Then all of that type of resource will be shown. You can
search within the list with `/` and press `Enter` to drill down
further. You can also press `Ctrl-a` to bring up the list of available
resource types and use xray mode with `:xray deployments`.

Check out the quick demo video below to see just a short bit of what
`k9s` has to offer:

<video controls width="480" height="270" src="https://dustymabecom.sfo2.digitaloceanspaces.com/2020-07-18_k9s.mp4"></video>
