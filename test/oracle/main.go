// The oracle for the table generators. It prints properties that the
// Go standard library, golang.org/x/text and the ICU library hold. Each
// mode prints plain text that the generators compare with their own
// tables.
package main

/*
#cgo LDFLAGS: -l:libicuuc.so.78
#include <stdint.h>
int32_t u_charMirror_78(int32_t c);
double u_getNumericValue_78(int32_t c);
int32_t u_charName_78(int32_t codepoint, int32_t nameChoice, char* buffer, int32_t bufferLength, int32_t* err);
int32_t u_charDirection_78(int32_t c);
int32_t u_strToTitle_78(uint16_t* dest, int32_t destCapacity, const uint16_t* src, int32_t srcLength, const uint16_t* localeID, const uint16_t* pivot, int32_t* err);
*/
import "C"

import (
	"bufio"
	"fmt"
	"os"
	"sort"
	"strings"
	"unicode"
	"unicode/utf16"
	"unsafe"

	"golang.org/x/text/cases"
	"golang.org/x/text/language"
	"golang.org/x/text/unicode/bidi"
	"golang.org/x/text/unicode/norm"
	"golang.org/x/text/width"
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
	case "catgroup":
		// The group of the general category of every code point, as the
		// runs of the group letter. The surrogates take the other group.
		runs(func(r rune) string {
			switch {
			case unicode.In(r, unicode.L):
				return "L"
			case unicode.In(r, unicode.M):
				return "M"
			case unicode.In(r, unicode.N):
				return "N"
			case unicode.In(r, unicode.P):
				return "P"
			case unicode.In(r, unicode.S):
				return "S"
			case unicode.In(r, unicode.Z):
				return "Z"
			}
			return "C"
		}, func(v string) bool { return false }, true)
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
	case "script":
		// The script name of every code point, from the tables of the
		// standard library. The names match the file of the standard.
		names := make([]string, len(unicode.Scripts))
		i := 0
		for name := range unicode.Scripts {
			names[i] = name
			i++
		}
		sort.Strings(names)
		who := make([]int16, 0x110000)
		for i := range who {
			who[i] = -1
		}
		for k, name := range names {
			for _, r := range unicode.Scripts[name].R16 {
				for c := uint16(r.Lo); c <= r.Hi; c += r.Stride {
					who[c] = int16(k)
					if c > 0xFFFF-r.Stride {
						break
					}
				}
			}
			for _, r := range unicode.Scripts[name].R32 {
				for c := r.Lo; c <= r.Hi; c += r.Stride {
					who[c] = int16(k)
					if c > 0x10FFFF-r.Stride {
						break
					}
				}
			}
		}
		start := 0
		for c := 1; c <= 0x110000; c++ {
			if c != 0x110000 && who[c] == who[start] {
				continue
			}
			label := "Unknown"
			if who[start] >= 0 {
				label = names[who[start]]
			}
			fmt.Fprintf(w, "%04X %04X %s\n", start, c-1, label)
			start = c
		}
	case "width":
		kind := map[width.Kind]string{
			width.Neutral:            "N",
			width.EastAsianNarrow:    "Na",
			width.EastAsianAmbiguous: "A",
			width.EastAsianWide:      "W",
			width.EastAsianFullwidth: "F",
			width.EastAsianHalfwidth: "H",
		}
		runs(func(r rune) string { return kind[width.LookupRune(r).Kind()] },
			func(v string) bool { return false }, false)
	case "bidi":
		// The trie of the package collapses the format characters into
		// one class. The list below holds the class of each of them.
		controls := map[rune]string{
			0x202A: "LRE", 0x202B: "RLE", 0x202C: "PDF", 0x202D: "LRO",
			0x202E: "RLO", 0x2066: "LRI", 0x2067: "RLI", 0x2068: "FSI",
			0x2069: "PDI", 0x200E: "L", 0x200F: "R", 0x061C: "AL",
		}
		names := map[bidi.Class]string{
			bidi.L: "L", bidi.R: "R", bidi.EN: "EN", bidi.ES: "ES",
			bidi.ET: "ET", bidi.AN: "AN", bidi.CS: "CS", bidi.B: "B",
			bidi.S: "S", bidi.WS: "WS", bidi.ON: "ON", bidi.BN: "BN",
			bidi.NSM: "NSM", bidi.AL: "AL",
		}
		runs(func(r rune) string {
			if n, ok := controls[r]; ok {
				return n
			}
			p, _ := bidi.LookupRune(r)
			return names[p.Class()]
		}, func(v string) bool { return false }, true)
	case "bidiicu":
		// The direction class of every code point, from the ICU library.
		// ICU fills the defaults of the file of the standard. The order
		// is the enum of the ICU library, checked against known letters.
		dirs := []string{"L", "R", "EN", "ES", "ET", "AN", "CS", "B",
			"S", "WS", "ON", "LRE", "LRO", "AL", "RLE", "RLO", "PDF",
			"NSM", "BN", "FSI", "LRI", "RLI", "PDI"}
		runs(func(r rune) string {
			return dirs[C.u_charDirection_78(C.int32_t(r))]
		}, func(v string) bool { return false }, true)
	case "mirror":
		for r := rune(0); r <= 0x10FFFF; r++ {
			m := C.u_charMirror_78(C.int32_t(r))
			if int32(m) != int32(r) {
				fmt.Fprintf(w, "%04X %04X\n", int(r), int(m))
			}
		}
	case "numeric":
		// ICU gives this value when the code point has no numeric value.
		const none = -1.23456789e+08
		for r := rune(0); r <= 0x10FFFF; r++ {
			d := float64(C.u_getNumericValue_78(C.int32_t(r)))
			if d == none {
				continue
			}
			fmt.Fprintf(w, "%04X %v\n", int(r), d)
		}
	case "name":
		for r := rune(0); r <= 0x10FFFF; r++ {
			if isSurrogate(r) {
				continue
			}
			n := u_charName(int(r))
			if n != "" {
				fmt.Fprintf(w, "%04X %s\n", int(r), n)
			}
		}
	case "utf16":
		// Each input line holds the code points of a text in hex, then a
		// bar, then the byte order. The output holds the UTF-16 bytes of
		// the text in hex and the number of the units.
		sc := bufio.NewScanner(os.Stdin)
		sc.Buffer(make([]byte, 1<<20), 1<<20)
		for sc.Scan() {
			body, order, _ := strings.Cut(sc.Text(), "|")
			order = strings.TrimSpace(order)
			var cps []rune
			for _, h := range strings.Fields(body) {
				var r rune
				fmt.Sscanf(h, "%X", &r)
				cps = append(cps, r)
			}
			units := utf16.Encode(cps)
			var sb strings.Builder
			for i, u := range units {
				if i > 0 {
					sb.WriteByte(' ')
				}
				if order == "be" {
					fmt.Fprintf(&sb, "%02X %02X", byte(u>>8), byte(u))
				} else {
					fmt.Fprintf(&sb, "%02X %02X", byte(u), byte(u>>8))
				}
			}
			fmt.Fprintf(w, "%s|%d\n", sb.String(), len(units))
		}
	case "fullcase":
		// Each input line holds one code point in hex. The output holds
		// the full upper case and the full lower case of it, separated
		// by a tab.
		up := cases.Upper(language.Und)
		low := cases.Lower(language.Und)
		sc := bufio.NewScanner(os.Stdin)
		sc.Buffer(make([]byte, 1<<20), 1<<20)
		for sc.Scan() {
			var r rune
			fmt.Sscanf(sc.Text(), "%X", &r)
			s := string(r)
			fmt.Fprintf(w, "%s\t%s\n", hexes(up.String(s)), hexes(low.String(s)))
		}
	case "icetitle":
		// Each input line holds the code points of one text in hex,
		// separated by spaces. The output holds the title case of the
		// text from the ICU library.
		sc := bufio.NewScanner(os.Stdin)
		sc.Buffer(make([]byte, 1<<20), 1<<20)
		for sc.Scan() {
			fields := strings.Fields(sc.Text())
			src := make([]uint16, 0, len(fields))
			for _, f := range fields {
				var v rune
				fmt.Sscanf(f, "%X", &v)
				src = append(src, uint16(v))
			}
			dest := make([]uint16, 4*len(src)+16)
			var err C.int32_t
			n := C.u_strToTitle_78((*C.uint16_t)(unsafe.Pointer(&dest[0])),
				C.int32_t(len(dest)), (*C.uint16_t)(unsafe.Pointer(&src[0])),
				C.int32_t(len(src)), nil, nil, &err)
			if err != 0 {
				fmt.Fprintln(w, "error")
				continue
			}
			out := make([]rune, 0, n)
			for i := 0; i < int(n); i++ {
				out = append(out, rune(dest[i]))
			}
			fmt.Fprintf(w, "%s\n", hexes(string(out)))
		}
	case "titlecp":
		// The title case of every code point. The lines hold the code
		// points whose title case differs from the code point.
		t := cases.Title(language.Und)
		for r := rune(0); r <= 0x10FFFF; r++ {
			if isSurrogate(r) {
				continue
			}
			s := t.String(string(r))
			if s != string(r) {
				fmt.Fprintf(w, "%04X %s\n", r, hexes(s))
			}
		}
	case "title":
		// Each input line holds the code points of one text in hex,
		// separated by spaces. The output holds the title case of the
		// text in the same form.
		t := cases.Title(language.Und)
		sc := bufio.NewScanner(os.Stdin)
		sc.Buffer(make([]byte, 1<<20), 1<<20)
		for sc.Scan() {
			fields := strings.Fields(sc.Text())
			var b strings.Builder
			for _, f := range fields {
				var v rune
				fmt.Sscanf(f, "%X", &v)
				b.WriteRune(v)
			}
			fmt.Fprintf(w, "%s\n", hexes(t.String(b.String())))
		}
	}
	w.Flush()
}

// The name of a code point in the ICU library. Empty when it has none.
func u_charName(r int) string {
	var err C.int32_t
	buf := make([]byte, 128)
	C.u_charName_78(C.int32_t(r), 0, (*C.char)(unsafe.Pointer(&buf[0])), C.int32_t(len(buf)), &err)
	if err != 0 {
		return ""
	}
	for i, b := range buf {
		if b == 0 {
			return string(buf[:i])
		}
	}
	return ""
}
