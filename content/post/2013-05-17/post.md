---
title: "Easy getopt for a BASH script"
tags:
date: "2013-05-17"
published: true
---

[getopt](http://en.wikipedia.org/wiki/Getopt) is extremely useful for
quickly being able to add options and arguments to your program without
having to worry much about the parsing yourself. There are getopt
libraries for many languages but what about BASH? It turns out there are
actually two versions of getopt that you can use in your BASH scripts; a
command line utility `getopt` provided by the util-linux package, and a
bash builtin `getopts`. I have provided a brief overview of each in the
following sections.

#### *getopt: The command line utility*

\
An example of a bash script using `getopt` to allow the user to specify
one of three colors (blue, red, or green) is shown below. The user can
specify `-b` to imply the color is blue or can specify `--color=blue` to
do the same. If the user uses the long option `--color` they must
specify an argument to denote what color.\
\

```nohighlight
#!/bin/bash

# Call getopt to validate the provided input. 
options=$(getopt -o brg --long color: -- "$@")
[ $? -eq 0 ] || { 
    echo "Incorrect options provided"
    exit 1
}
eval set -- "$options"
while true; do
    case "$1" in
    -b)
        COLOR=BLUE
        ;;
    -r)
        COLOR=RED
        ;;
    -g)
        COLOR=GREEN
        ;;
    --color)
        shift; # The arg is next in position args
        COLOR=$1
        [[ ! $COLOR =~ BLUE|RED|GREEN ]] && {
            echo "Incorrect options provided"
            exit 1
        }
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done

echo "Color is $COLOR"
exit 0;
```

\
And here are the outputs from some test runs:\
\

```nohighlight
dusty@media: content>./test -b
Color is BLUE
dusty@media: content>./test -r
Color is RED
dusty@media: content>./test -g
Color is GREEN
dusty@media: content>./test -z
getopt: invalid option -- 'z'
Incorrect options provided
dusty@media: content>./test --color=BLUE
Color is BLUE
dusty@media: content>./test --color
getopt: option '--color' requires an argument
Incorrect options provided
dusty@media: content>./test --color=YELLOW
Incorrect options provided
```

\

#### *getopts: The bash builtin*

\
We can almost exactly perform the same task with the `getopts` builtin.
Unfortunately the `getopts` builtin does not support long options so I
created a new `-c` short option and added a `:` to the line to specify
that it takes an argument (just like `--color` from the first example).
The code is shown below. Notice that `getopts` actually uses the
`$OPTARG` variable for options that have arguments which makes for easy
to read code.\
\

```nohighlight
#!/bin/bash

while getopts "brgc:" OPTION; do
    case $OPTION in
    b)
        COLOR=BLUE
        ;;
    r)
        COLOR=RED
        ;;
    g)
        COLOR=GREEN
        ;;
    c)
        COLOR=$OPTARG
        [[ ! $COLOR =~ BLUE|RED|GREEN ]] && {
            echo "Incorrect options provided"
            exit 1
        }
        ;;
    *)
        echo "Incorrect options provided"
        exit 1
        ;;
    esac
done

echo "Color is $COLOR"
exit 0;
```

\
And finally a similar set of output from test runs:

```nohighlight
dusty@media: content>./test2 -b
Color is BLUE
dusty@media: content>./test2 -r
Color is RED
dusty@media: content>./test2 -g
Color is GREEN
dusty@media: content>./test2 -z
./test2: illegal option -- z
Incorrect options provided
dusty@media: content>./test2 -c BLUE
Color is BLUE
dusty@media: content>./test2 -c
./test2: option requires an argument -- c
Incorrect options provided
dusty@media: content>./test2 -c YELLOW
Incorrect options provided
dusty@media: content>
```

\
Cheers!\
\
Dusty Mabe
