---
title: "Running Benchmarks With the Phoronix Test Suite!"
tags:
date: "2012-12-30"
draft: false
---

Benchmarking software can be invaluable when testing new
hardware/software configurations. The [Phoronix Test
Suite](http://www.phoronix-test-suite.com) is a collection of open
source software benchmarks that are fairly easy to use and the results
are presented in a such a way that is easy to understand; even if you
don't understand the tests that were run. Today I'll give a brief run
down of how to install the test suite and run the benchmarks.\
\
Phoronix can be used on almost all operating systems. The only
requirement of the Phoronix Test Suite is PHP. For this demonstration I
am using a Fedora 17 virtual machine, however your experience should be
fairly similar on whatever Linux distribution you may be using.\
\
The first thing I needed to do was install a few PHP packages. A quick
call to `yum` will take care of this for us:\

```nohighlight
[root@guest1 ~]# yum -y install php-cli php-xml php-gd
...
```

\
Next I downloaded and extracted the software and ran their `install.sh`
script to install it.\

```nohighlight
[root@guest1 phoronix]# mkdir /tmp/phoronix
[root@guest1 phoronix]# cd /tmp/phoronix
[root@guest1 phoronix]# 
[root@guest1 phoronix]# wget --quiet --output-document=phoronix-test-suite-4.2.0.tar.gz http://www.phoronix-test-suite.com/download.php?file=phoronix-test-suite-4.2.0
[root@guest1 phoronix]# 
[root@guest1 phoronix]# tar xf phoronix-test-suite-4.2.0.tar.gz
[root@guest1 phoronix]#
[root@guest1 phoronix]# cd phoronix-test-suite
[root@guest1 phoronix-test-suite]#
[root@guest1 phoronix-test-suite]# ./install-sh

Phoronix Test Suite Installation Completed

Executable File: /usr/bin/phoronix-test-suite
Documentation: /usr/share/doc/phoronix-test-suite/
Phoronix Test Suite Files: /usr/share/phoronix-test-suite/

[root@guest1 phoronix-test-suite]#
```

\
Now that the phoronix software is installed you can run any of the
phoronix tests by using the `phoronix-test-suite` command. You can run
the ` phoronix-test-suite list-suites` command to view what test suites
are available for you to use. Some of the most notable ones are the
***disk*** test suite and the ***cpu*** test suites.\
\
**NOTE:** A license message will appear upon the first run of
`phoronix-test-suite` and will require you to answer a few questions.\
\
In order to view the actual tests within the test suite the
`phoronix-test-suite info` command is useful. For example, to see the
tests within the ***disk*** test suite you would call
`phoronix-test-suite info disk` as is done below:\

```nohighlight
[root@guest1 phoronix-test-suite]# phoronix-test-suite info disk


Phoronix Test Suite v4.2.0
Disk Test Suite

Run Identifier: pts/disk-1.2.1
Suite Version: 1.2.1
Maintainer: Michael Larabel
Suite Type: Disk
Unique Tests: 13
Suite Description: This test suite is designed to contain real-world disk and file-system tests.

pts/disk-1.2.1
  * pts/compress-gzip
  * pts/sqlite
  * pts/apache
  * pts/pgbench
  * pts/compilebench
  * pts/iozone
  * pts/dbench
  * pts/fs-mark
  * pts/fio
  * pts/tiobench
  * pts/postmark
  * pts/aio-stress
  * pts/unpack-linux

[root@guest1 phoronix-test-suite]#
```

\
So how do you run these tests? I like to run my tests in *batch* mode so
that no questions are asked to me during the test execution. To set this
up run the `phoronix-test-suite batch-setup` command in order to answer
a few questions that will apply to all of the future *batch* runs. The
answers that I chose are shown in the output below:\

```nohighlight
[root@guest1 phoronix-test-suite]# phoronix-test-suite batch-setup

These are the default configuration options for when running the Phoronix Test Suite in a batch mode (i.e. running phoronix-test-suite batch-benchmark universe). Running in a batch mode is designed to be as autonomous as possible, except for where you'd like any end-user interaction.

    Save test results when in batch mode (Y/n): Y
    Open the web browser automatically when in batch mode (y/N): N
    Auto upload the results to OpenBenchmarking.org (Y/n): n
    Prompt for test identifier (Y/n): n
    Prompt for test description (Y/n): n
    Prompt for saved results file-name (Y/n): n
    Run all test options (Y/n): Y

Batch settings saved.

[root@guest1 phoronix-test-suite]#
```

\
Now that we have *batch* set up we can run a few tests using the
`phoronix-test-suite batch-benchmark` command. I chose to run the
*pts/iozone* and *pts/compress-7zip* benchmarks.\


```nohighlight
[root@guest1 phoronix-test-suite]# phoronix-test-suite batch-benchmark pts/iozone pts/compress-7zip
...
```

**NOTE:** You can see the full output [here](/2012-12-30/output.txt).

\
It should take quite some time for the tests to run. After the tests are
complete the results are stored in the
` ~/.phoronix-test-suite/test-results/` directory. For example, from my
test run all files were stored in
`~/.phoronix-test-suite/test-results/2012-12-30-1234/`. The best way I
have found to view the test results is to fire up a web browser and
point it to the index.html file within the test results directory:\

```nohighlight
[root@guest1 phoronix-test-suite]# firefox ~/.phoronix-test-suite/test-results/2012-12-30-1234/index.html
```

\
An example of the test results output for the test I ran can be found
[here](/2012-12-30/2012-12-30-1234/index.html)\
\
The test results for a single test run are nice, but the graphs really
help when comparing runs from multiple tests. i.e you tweak some setting
and then run the benchmarks again to see the performance impact. I
performed two runs of the *compress-7zip* benchmark to do just this. The
two test runs were placed into the `2012-12-30-2102` and
`2012-12-30-2106` directories within the test-results directory. In
order to compare the outputs side by side the
`phoronix-test-suite merge-results` command is used.\
\

```nohighlight
[root@guest1 phoronix-test-suite]# phoronix-test-suite merge-results 2012-12-30-2102 2012-12-30-2106
Merged Results Saved To:
/root/.phoronix-test-suite/test-results/merge-1844/composite.xml

    Do you want to view the results in your web browser (y/N): N

[root@guest1 phoronix-test-suite]#
```

\
For these test runs I didn't tweak any settings on the system so they
are pretty much the same result, but take a look at the merged test
results [here](/2012-12-30/merge-1844/index.html) to get an idea
of what I mean about the side-by-side comparison.\
\
Take an opportunity to check out the phoronix
[documentation](/2012-12-30/phoronix-test-suite.pdf) or the
`phoronix-test-suite` man page to discover more features!\
\
Happy Benchmarking!\
\
Dusty Mabe
