// The oracle for the table generators. It prints properties that the
// Go standard library and golang.org/x/text hold. Each mode prints
// plain text that the generators compare with their own tables.
package main

import (
	"bufio"
	"fmt"
	"os"
	"strings"
	"unicode"

	"golang.org/x/text/unicode/norm"
)

var cats = []string{"Cn", "Lu", "Ll", "Lt", "Lm", "Lo", "Mn", "Mc", "Me", "Nd", "Nl", "No",
	"Pc", "Pd", "Ps", "Pe", "Pi", "Pf", "Po", "Sm", "Sc", "Sk", "So", "Zs", "Zl", "Zp", "Cc", "Cf", "Cs", "Co"}

func category(r rune) string {
	for _, name := range cats[1:] {
		if unicode.Is(unicode.Categories[name], r) {
			return name
		}
	}
	return "Cn"
}

func hexes(s string) string {
	var parts []string
	for _, r := range s {
		parts = append(parts, fmt.Sprintf("%04X", r))
	}
	return strings.Join(parts, " ")
}

func isSurrogate(r rune) bool { return r >= 0xD800 && r <= 0xDFFF }

// runs prints the runs of equal values over all code points.
func runs(value func(r rune) string, skip func(v string) bool, includeSurrogates bool) {
	w := bufio.NewWriter(os.Stdout)
	defer w.Flush()
	start := rune(0)
	prev := value(0)
	for r := rune(1); r <= 0x110000; r++ {
		cur := ""
		if r < 0x110000 {
			if isSurrogate(r) && !includeSurrogates {
				cur = prev
			} else {
				cur = value(r)
			}
		}
		if r == 0x110000 || cur != prev {
			if !skip(prev) {
				fmt.Fprintf(w, "%04X %04X %s\n", start, r-1, prev)
			}
			start = r
			prev = cur
		}
	}
}

func main() {
	mode := os.Args[1]
	w := bufio.NewWriter(os.Stdout)
	switch mode {
	case "version":
		fmt.Println(unicode.Version, norm.Version)
	case "cat":
		runs(category, func(v string) bool { return false }, true)
	case "ccc":
		runs(func(r rune) string { return fmt.Sprint(norm.NFC.PropertiesString(string(r)).CCC()) },
			func(v string) bool { return v == "0" }, false)
	case "nfd", "nfkd", "nfc", "nfkc":
		forms := map[string]norm.Form{"nfd": norm.NFD, "nfkd": norm.NFKD, "nfc": norm.NFC, "nfkc": norm.NFKC}
		f := forms[mode]
		for r := rune(0); r <= 0x10FFFF; r++ {
			if isSurrogate(r) {
				continue
			}
			s := string(r)
			t := f.String(s)
			if t != s {
				fmt.Fprintf(w, "%04X %s\n", r, hexes(t))
			}
		}
	case "pairs":
		sc := bufio.NewScanner(os.Stdin)
		for sc.Scan() {
			var a, b rune
			fmt.Sscanf(sc.Text(), "%X %X", &a, &b)
			fmt.Fprintf(w, "%s\n", hexes(norm.NFC.String(string(a)+string(b))))
		}
	case "nt":
		// Each input line holds five columns of code points, separated by
		// bars. The output holds the four forms of each column.
		sc := bufio.NewScanner(os.Stdin)
		sc.Buffer(make([]byte, 1<<20), 1<<20)
		for sc.Scan() {
			var outs []string
			for _, col := range strings.Split(sc.Text(), "|") {
				var sb strings.Builder
				for _, h := range strings.Fields(col) {
					var r rune
					fmt.Sscanf(h, "%X", &r)
					sb.WriteRune(r)
				}
				text := sb.String()
				for _, f := range []norm.Form{norm.NFC, norm.NFD, norm.NFKC, norm.NFKD} {
					outs = append(outs, hexes(f.String(text)))
				}
			}
			fmt.Fprintln(w, strings.Join(outs, "|"))
		}
	case "qc":
		forms := map[string]norm.Form{"nfc": norm.NFC, "nfd": norm.NFD, "nfkc": norm.NFKC, "nfkd": norm.NFKD}
		f := forms[os.Args[2]]
		w.Flush()
		runs(func(r rune) string {
			if f.IsNormalString(string(r)) {
				return "Y"
			}
			return "N"
		}, func(v string) bool { return v == "Y" }, false)
	case "upper", "lower":
		for r := rune(0); r <= 0x10FFFF; r++ {
			if isSurrogate(r) {
				continue
			}
			var t rune
			if mode == "upper" {
				t = unicode.ToUpper(r)
			} else {
				t = unicode.ToLower(r)
			}
			if t != r {
				fmt.Fprintf(w, "%04X %04X\n", r, t)
			}
		}
	}
	w.Flush()
}
