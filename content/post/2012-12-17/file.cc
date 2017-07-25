#include <stdio.h>
#include <stdlib.h>
// A program that will square two integers and then find the LCM
// of the resulting two integers. 

class Math {
    public:
        int squared(int x)       { return x*x; }
        int modulo(int x, int y) { return x%y; }
        int plus(int x, int y)   { return x+y; }
};


int main(int argc, char *argv[]) {
    int x, y, x2, y2, tmp;
    if (argc != 3) return 0; 

    Math* m = new Math;

    x = atoi(argv[1]);  
    y = atoi(argv[2]);
    x2       = m->squared(x);
    y2 = tmp = m->squared(y);

    while (1) {
        if (m->modulo(tmp,x2) == 0) break;
        tmp = m->plus(tmp,y2);
    }
    printf("LCM is %d\n", tmp);
}


