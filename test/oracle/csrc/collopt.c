/* The sign of the comparison of two texts by the ICU collator.
   Usage: collopt <locale> <strength> <alternate> <numeric> <casefirst>
   Each text is a line of hex code points, separated by a bar.
   The program prints one sign per line: -1, 0 or 1.
   The strength: 0 primary, 1 secondary, 2 tertiary, 15 identical.
   The alternate handling: 20 shifted, 21 non-ignorable.
   The numeric order: 16 off, 17 on.
   The case order: 16 off, 24 lower first, 25 upper first.
   The build needs the headers and the libraries of ICU 79.1. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unicode/ucol.h>
#include <unicode/ustring.h>
#include <unicode/utypes.h>
/* The code points of the hex text in s, as UTF-16 code units. A code
   point above U+FFFF takes two units. Gives the number of the units. */
static int32_t parse_cps(char *s, UChar *out) {
    int32_t n = 0;
    char *p = strtok(s, " \n");
    while (p) {
        unsigned cp = strtoul(p, 0, 16);
        if (cp > 0xFFFF) {
            out[n++] = 0xD800 + ((cp-0x10000)>>10);
            out[n++] = 0xDC00 + ((cp-0x10000)&0x3FF);
        } else {
            out[n++] = cp;
        }
        p = strtok(0, " \n");
    }
    return n;
}

int main(int argc, char **argv) {
    UErrorCode st = U_ZERO_ERROR;
    const char *locale = argc > 1 ? argv[1] : "und";
    int strength = argc > 2 ? atoi(argv[2]) : UCOL_TERTIARY;
    int alternate = argc > 3 ? atoi(argv[3]) : UCOL_NON_IGNORABLE;
    int numeric = argc > 4 ? atoi(argv[4]) : UCOL_OFF;
    int casefirst = argc > 5 ? atoi(argv[5]) : UCOL_OFF;
    UCollator *c = ucol_open(locale, &st);
    if (U_FAILURE(st)) { printf("E open %d\n", st); return 1; }
    UErrorCode st1 = U_ZERO_ERROR;
    ucol_setStrength(c, strength);
    ucol_setAttribute(c, UCOL_ALTERNATE_HANDLING, alternate, &st1);
    ucol_setAttribute(c, UCOL_NUMERIC_COLLATION, numeric, &st1);
    ucol_setAttribute(c, UCOL_CASE_FIRST, casefirst, &st1);
    if (U_FAILURE(st1)) { printf("E attribute %d\n", st1); return 1; }
    char line[1<<20];
    while (fgets(line, sizeof line, stdin)) {
        char *bar = strchr(line, '|');
        if (!bar) { continue; }
        *bar = 0;
        UChar a[1<<19], b[1<<19];
        int32_t na = parse_cps(line, a);
        int32_t nb = parse_cps(bar + 1, b);
        int32_t r = ucol_strcoll(c, a, na, b, nb);
        printf("%d\n", r < 0 ? -1 : (r > 0 ? 1 : 0));
    }
    ucol_close(c);
    return 0;
}
