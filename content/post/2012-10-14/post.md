---
title: "Trace Function Calls Using GDB"
tags:
date: "2012-10-14"
published: true
---

Sometimes it is easier to debug when you are able to view a call trace
of all function calls in a particular program. This is especially true
when working with code that isn't yours or when debugging issues such as
infinite loops in your own code. The way I typically do this is by
creating a GDB commands file that defines breakpoints for each function
I would like to see in the trace.\
\
For each function breakpoint, I instruct GDB to print a short backtrace
and then continue execution. I can then stop the program run at any time
using `CTRL-C` and observe where the program is, what functions are
being called, and what arguments they are being called with.\
\
To illustrate this, consider the following short program that accepts
two arguments. It takes these two arguments, squares them, and then
finds the lowest common multiple of their squares. This means if you
pass in 4 and 10, it will find the LCM of 16 and 100.\
\
**NOTE:** I have defined functions for basic operations such as squaring
a number and adding two numbers just for illustrative purposes.\
\

```nohighlight
#include <stdio.h>
#include <stdlib.h>
// A program that will square two integers and then find the LCM
// of the resulting two integers. 

int squared(int x)       { return x*x; }
int modulo(int x, int y) { return x%y; }
int plus(int x, int y)   { return x+y; }

int main(int argc, char *argv[]) {
    int x, y, x2, y2, tmp;
    if (argc != 3) return 0;

    x = atoi(argv[1]);
    y = atoi(argv[2]);
    x2       = squared(x);
    y2 = tmp = squared(y);

    while (1) {
        if (modulo(tmp,x2) == 0) break;
        tmp = plus(tmp,y2);
    }
    printf("LCM is %d\n", tmp);
}
```

\
I then use the following GDB commands file to define the breakpoints and
the commands to run for each breakpoint.\
\

```nohighlight
set args 4 10

break squared
command
silent
backtrace 1
continue
end

break modulo
command
silent
backtrace 1
continue
end

break plus
command
silent
backtrace 1
continue
end

run
```

\
After compiling my program (making sure to use `gcc -g` to add in debug
information) I can run the program using `gdb` and view the trace.\
\

```nohighlight
dustymabe@laptop: gdbpost>gdb -quiet -command=gdb_commands ./a.out 
Reading symbols from
/content/gdbpost/a.out...done.
Breakpoint 1 at 0x400533: file file.c, line 6.
Breakpoint 2 at 0x400546: file file.c, line 7.
Breakpoint 3 at 0x40055f: file file.c, line 8.
#0  squared (x=4) at file.c:6
#0  squared (x=10) at file.c:6
#0  modulo (x=100, y=16) at file.c:7
#0  plus (x=100, y=100) at file.c:8
#0  modulo (x=200, y=16) at file.c:7
#0  plus (x=200, y=100) at file.c:8
#0  modulo (x=300, y=16) at file.c:7
#0  plus (x=300, y=100) at file.c:8
#0  modulo (x=400, y=16) at file.c:7
LCM is 400
[Inferior 1 (process 4214) exited with code 013]
Missing separate debuginfos, use: debuginfo-install
glibc-2.15-56.fc17.x86_64
(gdb) quit
```
