// The word and line breaks of ICU, for a file of texts. Build it against ICU 79.1 and set LSTM_DIR to the folder that holds the compiled model files.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unicode/ubrk.h>
#include <unicode/ustring.h>
#include <unicode/putil.h>
#include <unicode/uclean.h>
/* usage: brk word|line  : reads lines of hex code points on stdin, prints the breaks */
int main(int argc, char **argv) {
    const char *dir = getenv("LSTM_DIR");
    if (dir) u_setDataDirectory(dir);
    UBreakIteratorType t = (argc > 1 && argv[1][0]=='l') ? UBRK_LINE : UBRK_WORD;
    char line[1<<20];
    while (fgets(line, sizeof line, stdin)) {
        UChar buf[1<<19]; int n = 0;
        char *p = strtok(line, " ;\n");
        while (p) { unsigned c = strtoul(p, 0, 16);
            if (c > 0xFFFF) { buf[n++] = 0xD800 + ((c-0x10000)>>10); buf[n++] = 0xDC00 + ((c-0x10000)&0x3FF);} else buf[n++]=c;
            p = strtok(0, " ;\n"); }
        UErrorCode st = U_ZERO_ERROR;
        UBreakIterator *b = ubrk_open(t, "", buf, n, &st);
        if (U_FAILURE(st)) { printf("E %d\n", st); continue; }
        int32_t i = ubrk_first(b);
        while (i != UBRK_DONE) { printf("%d ", i); i = ubrk_next(b); }
        printf("\n"); ubrk_close(b);
    }
    return 0;
}
