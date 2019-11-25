#include <stdio.h>
#include <math.h>

int main(void)
{
    int c;
    double d;
    int e;

    printf("sin_table:\n");
    for (c = 0; c < 128; c++) {
        if ((c & 7) == 0)
            printf("\tdb ");
        d = sin((c * 360 / 128) * 3.14159 / 180) * 256;
        if (d < 0)
            e = (d - 0.5);
        else
            e = (d + 0.5);
        printf("0x%02x", e & 0xff);
        if ((c & 7) == 7)
            printf("\n");
        else
            printf(",");
    }

    /* Planned but never used */
    printf("\n");
    printf("tan_table:\n");
    for (c = 0; c <= 42; c++) {
        if ((c & 7) == 0)
            printf("\tdb ");
        e = 128 / tan(((c - 21) * 360 / 128) * 3.14159 / 180);
        printf("0x%02x", e);
        if ((c & 7) == 7)
            printf("\n");
        else
            printf(",");
    }
}

