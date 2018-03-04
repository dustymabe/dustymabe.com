---
title: "Pruning Policy for Specific Branches of OSTree Repos"
tags: [ fedora, atomic ]
date: "2018-03-04"
published: true
---


# Introduction

In Fedora we are [moving to a unified OSTree repo structure](https://lists.fedoraproject.org/archives/list/rel-eng@lists.fedoraproject.org/thread/KLN5L33BIR3ZEHC5RIG4NXGO7LT6HBXJ/)
where there is a
single OSTree repository that is the remote for all branches of Fedora
(rawhide, branched, stable, etc). As part of this we want to be able
to define different retention policies for different branches within
the repository. For rawhide we'll retain a few weeks worth of commits,
but for stable we don't want to prune any of the commits.

Allowing for this flexibility required an [RFE](https://github.com/ostreedev/ostree/issues/1115)
against OSTree upstream and it was [implemented](https://github.com/ostreedev/ostree/pull/1127) 
by adding the `--only-branch` and `--retain-branch-depth` options
to `ostree prune`. Let's give them a test drive.

# Setting up a test repo

We'll create a new test repo and then pull OSTree content for the 
last 11 commits (`--depth=10`) from a few refs.

```nohighlight
[dustymabe@host ~]$ mkdir repo
[dustymabe@host tmp]$ cd repo
[dustymabe@host repo]$ ostree init --repo=./
[dustymabe@host repo]$ ostree remote add f27 https://kojipkgs.fedoraproject.org/atomic/27/ --no-gpg-verify
[dustymabe@host repo]$ 
[dustymabe@host repo]$ sudo ostree pull f27:fedora/27/x86_64/atomic-host --depth=10 

5688 metadata, 34013 content objects fetched; 1338909 KiB transferred in 71 seconds                                                                                                                                                                             
[dustymabe@host repo]$ 
[dustymabe@host repo]$ sudo ostree pull f27:fedora/27/aarch64/atomic-host --depth=10 

3189 metadata, 14266 content objects fetched; 788984 KiB transferred in 43 seconds                                                                                                                                                                              
[dustymabe@host repo]$ 
[dustymabe@host repo]$ sudo ostree pull f27:fedora/27/ppc64le/atomic-host --depth=10 

3012 metadata, 12942 content objects fetched; 842778 KiB transferred in 51 seconds 
[dustymabe@host repo]$ 
```

Now we have 3 refs in the repo, one for `x86_64`, `aarch64`, and `ppc64le`.

```nohighlight
[dustymabe@host repo]$ ostree refs
f27:fedora/27/ppc64le/atomic-host
f27:fedora/27/x86_64/atomic-host
f27:fedora/27/aarch64/atomic-host
```

Each of these refs have 11 commits in the history (10 + the commit the
ref is currently pointing to). We can show this by using a short
script.

```nohighlight
[dustymabe@host repo]$ cat count.sh                                                                                                                                                                                                                                   
#!/bin/bash                                                        
for ref in $(ostree refs); do                                      
    echo -en "$ref\t"                                              
    ostree log "$ref" --raw | grep '^commit' | wc -l               
done                                                               
[dustymabe@host repo]$ bash count.sh                      
f27:fedora/27/ppc64le/atomic-host       11                         
f27:fedora/27/x86_64/atomic-host        11                         
f27:fedora/27/aarch64/atomic-host       11
```

# Pruning content from a single ref

We'll start by pruning 2 commits from the `ppc64le` branch within the repo.
Before we actually prune let's do a dry run using `--no-prune` to get an idea of
what would happen:

```nohighlight
[dustymabe@host repo]$ sudo ostree prune --only-branch f27:fedora/27/ppc64le/atomic-host --depth=8 --no-prune
Total objects: 73077
Would delete: 3415 objects, freeing 0 bytes
[dustymabe@host repo]$ 
[dustymabe@host repo]$ bash count.sh 
f27:fedora/27/ppc64le/atomic-host       11
f27:fedora/27/x86_64/atomic-host        11
f27:fedora/27/aarch64/atomic-host       11
```

So we `Would delete: 3415 objects` from the repo if we ran this prune operation.
You can see from the count script that we didn't actually prune anything and
all refs still have 11 commits in the repo. Let's actually prune now:


```nohighlight
[dustymabe@host repo]$ sudo ostree prune --only-branch f27:fedora/27/ppc64le/atomic-host --depth=8
Total objects: 73077
Deleted 3415 objects, 242.0 MB freed
[dustymabe@host repo]$ 
[dustymabe@host repo]$ bash count.sh 
f27:fedora/27/ppc64le/atomic-host       9
f27:fedora/27/x86_64/atomic-host        11
f27:fedora/27/aarch64/atomic-host       11
```

In this case we pruned those 3415 objects and freed up 242 MB in the process.
We can see from the count script that we are down to 9 commits in the repo
for the `ppc64le` ref.


# Pruning different branches at different rates

In this case we want to prune different branches at differing rates.
We can either run two separate commands for this or we can use
the `--retain-branch-depth` option.

```nohighlight
[dustymabe@host repo]$ sudo ostree prune --only-branch f27:fedora/27/x86_64/atomic-host --only-branch f27:fedora/27/aarch64/atomic-host --depth=6 --retain-branch-depth f27:fedora/27/x86_64/atomic-host=7
Total objects: 69662
Deleted 8100 objects, 604.5 MB freed
[dustymabe@host repo]$ bash count.sh 
f27:fedora/27/ppc64le/atomic-host       9
f27:fedora/27/x86_64/atomic-host        8
f27:fedora/27/aarch64/atomic-host       7
```

In the above example we pruned the `aarch64` ref down to 7 commits, but we
only wanted to prune the `x86_64` ref to 8 commits. To do this we defined
a specific policy for the `x86_64` branch using 
`--retain-branch-depth f27:fedora/27/x86_64/atomic-host=7`. We can see from
the `count.sh` script that the counts are at 9, 8, and 7 for our various
refs.

# Pruning based on time

We don't only have to prune based on depth. We can also use the 
`--keep-younger-than` option to prune specific branches:

```nohighlight
[dustymabe@host repo]$ sudo ostree prune --keep-younger-than="10 days ago" --only-branch f27:fedora/27/ppc64le/atomic-host
Total objects: 61562
Deleted 5130 objects, 525.6 MB freed
[dustymabe@host repo]$ 
[dustymabe@host repo]$ bash count.sh 
f27:fedora/27/ppc64le/atomic-host       3
f27:fedora/27/x86_64/atomic-host        8
f27:fedora/27/aarch64/atomic-host       7
```

In this case we kept all commits that were younger than `10 days ago`.
This brought us down to 3 commits for the `ppc64le` branch.

# Fin

Now we know how to define/execute different policies for different branches
in an OSTree repo. This will help us in Fedora manage the size of our
repositories. 

**NOTE:** In the future we may be delivering OSTree content via a special
          RPM using [RPM-OSTree rojig](https://github.com/projectatomic/rpm-ostree/issues/1081) 
          instead of hosting an OSTree repository. Stay tuned for updates
          on that.
