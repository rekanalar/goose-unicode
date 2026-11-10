// The oracle for the table generators. It prints properties that the
// Go standard library, golang.org/x/text and the ICU library hold. Each
// mode prints plain text that the generators compare with their own
// tables.
package main

/*
#cgo LDFLAGS: -l:libicuuc.so.78 -l:libicui18n.so.78
#include <stdint.h>
#include <stdlib.h>
int32_t u_charMirror_78(int32_t c);
double u_getNumericValue_78(int32_t c);
int32_t u_charName_78(int32_t codepoint, int32_t nameChoice, char* buffer, int32_t bufferLength, int32_t* err);
int32_t u_charDirection_78(int32_t c);
int32_t u_strToTitle_78(uint16_t* dest, int32_t destCapacity, const uint16_t* src, int32_t srcLength, const uint16_t* localeID, const uint16_t* pivot, int32_t* err);
void* ubrk_open_78(int32_t type, const char* locale, const uint16_t* text, int32_t textLength, int32_t* status);
int32_t ubrk_next_78(void* bi);
int32_t ubrk_getRuleStatus_78(void* bi);
void ubrk_close_78(void* bi);
int32_t u_charFromName_78(int32_t nameChoice, const char* name, int32_t* err);
int32_t u_getIntPropertyValue_78(int32_t c, int32_t which);
const char* u_getPropertyValueName_78(int32_t property, int32_t value, int32_t nameChoice);
int32_t u_getBidiPairedBracket_78(int32_t c);
int32_t u_charDigitValue_78(int32_t c);
int32_t uscript_getScriptExtensions_78(int32_t c, int32_t* scripts, int32_t capacity, int32_t* err);
const char* uscript_getName_78(int32_t code);
void u_charAge_78(int32_t c, uint8_t* versionArray);
void* ucol_open_78(const char* loc, int32_t* err);
void ucol_close_78(void* col);
int32_t ucol_strcoll_78(void* col, const uint16_t* a, int32_t alen, const uint16_t* b, int32_t blen);
int32_t ucol_getSortKey_78(void* col, const uint16_t* src, int32_t len, uint8_t* key, int32_t cap);
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
	"golang.org/x/text/collate"
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
	case "icuprop":
		// The runs of the value of one ICU integer property, as the long
		// name of the value. The argument is the number of the property.
		var prop int
		fmt.Sscanf(os.Args[2], "%d", &prop)
		runs(func(r rune) string {
			v := C.u_getIntPropertyValue_78(C.int32_t(r), C.int32_t(prop))
			p := C.u_getPropertyValueName_78(C.int32_t(prop), v, 1)
			if p == nil {
				return fmt.Sprintf("#%d", int(v))
			}
			return C.GoString(p)
		}, func(v string) bool { return false }, true)
	case "icubracket":
		// The code points that have a paired bracket other than themselves.
		for r := rune(0); r <= 0x10FFFF; r++ {
			m := C.u_getBidiPairedBracket_78(C.int32_t(r))
			if int32(m) != int32(r) {
				fmt.Fprintf(w, "%04X %04X\n", int(r), int(m))
			}
		}
	case "icudigit":
		// The decimal digit value of every code point that has one.
		for r := rune(0); r <= 0x10FFFF; r++ {
			d := C.u_charDigitValue_78(C.int32_t(r))
			if d >= 0 {
				fmt.Fprintf(w, "%04X %d\n", int(r), int(d))
			}
		}
	case "icescriptext":
		// The runs of the script extensions of every code point. The value
		// is the sorted list of the long script names, joined by a comma.
		runs(func(r rune) string {
			var sc [64]C.int32_t
			var err C.int32_t
			n := int(C.uscript_getScriptExtensions_78(C.int32_t(r), &sc[0], 64, &err))
			names := make([]string, 0, n)
			for k := 0; k < n; k++ {
				names = append(names, C.GoString(C.uscript_getName_78(sc[k])))
			}
			sort.Strings(names)
			return strings.Join(names, ",")
		}, func(v string) bool { return false }, true)
	case "gocoll":
		// Each input line holds two texts in hex code points, separated
		// by a bar. The output holds the sign of the root collator of
		// the x/text package. The und locale is the root locale.
		col := collate.New(language.Und)
		sc := bufio.NewScanner(os.Stdin)
		sc.Buffer(make([]byte, 1<<20), 1<<20)
		for sc.Scan() {
			body, second, _ := strings.Cut(sc.Text(), "|")
			sign := func(text string) string {
				var b strings.Builder
				for _, f := range strings.Fields(text) {
					var v rune
					fmt.Sscanf(f, "%X", &v)
					b.WriteRune(v)
				}
				return b.String()
			}
			sa := sign(body)
			sb := sign(second)
			r := col.CompareString(sa, sb)
			fmt.Fprintln(w, r)
		}
	case "icecoll", "icekey":
		// Each input line holds two texts in hex code points, separated
		// by a bar. icecoll prints the sign of the ICU collator on the
		// und locale. icekey prints the byte sort key of the first text.
		// The locale is opened by name: a null name opens the locale of
		// the environment, which sorts case in another order.
		var st C.int32_t
		loc := C.CString("und")
		col := C.ucol_open_78(loc, &st)
		C.free(unsafe.Pointer(loc))
		if st != 0 {
			fmt.Fprintln(w, "open error")
			break
		}
		defer C.ucol_close_78(col)
		sc := bufio.NewScanner(os.Stdin)
		sc.Buffer(make([]byte, 1<<20), 1<<20)
		w.Flush()
		for sc.Scan() {
			body, second, _ := strings.Cut(sc.Text(), "|")
			sign := func(text string) []uint16 {
				units := []uint16{}
				for _, f := range strings.Fields(text) {
					var v rune
					fmt.Sscanf(f, "%X", &v)
					for _, u := range utf16.Encode([]rune{v}) {
						units = append(units, u)
					}
				}
				return units
			}
			ua := sign(body)
			if len(ua) == 0 {
				if strings.HasPrefix(second, "KEY") {
					fmt.Fprintln(w, "EMPTY")
					continue
				}
				fmt.Fprintln(w, "0")
				continue
			}
			if strings.HasPrefix(second, "KEY") {
				buf := make([]C.uint8_t, 4096)
				n := C.ucol_getSortKey_78(col, (*C.uint16_t)(unsafe.Pointer(&ua[0])),
					C.int32_t(len(ua)), &buf[0], C.int32_t(len(buf)))
				parts := make([]string, n)
				for i := 0; i < int(n); i++ {
					parts[i] = fmt.Sprintf("%02X", buf[i])
				}
				fmt.Fprintln(w, strings.Join(parts, " "))
				continue
			}
			ub := sign(second)
			fmt.Fprintln(w, C.ucol_strcoll_78(col, (*C.uint16_t)(unsafe.Pointer(&ua[0])),
				C.int32_t(len(ua)), (*C.uint16_t)(unsafe.Pointer(&ub[0])), C.int32_t(len(ub))))
		}
	case "iceage":
		// The runs of the age of every code point, as major.minor.
		runs(func(r rune) string {
			var v [4]C.uint8_t
			C.u_charAge_78(C.int32_t(r), &v[0])
			return fmt.Sprintf("%d.%d", int(v[0]), int(v[1]))
		}, func(v string) bool { return false }, true)
	case "fromname":
		// Each input line holds a name. The output holds the code point
		// in hex, or -1 when the ICU library knows no such name. A name
		// of a code point wins over an alias.
		sc := bufio.NewScanner(os.Stdin)
		sc.Buffer(make([]byte, 1<<20), 1<<20)
		for sc.Scan() {
			cn := C.CString(sc.Text())
			res := -1
			for _, choice := range []C.int32_t{0, 2, 3} {
				var err C.int32_t
				r := C.u_charFromName_78(choice, cn, &err)
				if err == 0 {
					res = int(r)
					break
				}
			}
			C.free(unsafe.Pointer(cn))
			if res < 0 {
				fmt.Fprintln(w, "-1")
			} else {
				fmt.Fprintf(w, "%04X\n", res)
			}
		}
	case "icelines":
		// Each input line holds the code points of one text in hex. The
		// output holds the break offsets of the ICU line iterator, in code
		// points, each followed by m for a hard break.
		sc := bufio.NewScanner(os.Stdin)
		sc.Buffer(make([]byte, 1<<20), 1<<20)
		for sc.Scan() {
			var units []uint16
			var starts []int
			idx := 0
			for _, f := range strings.Fields(sc.Text()) {
				var v rune
				fmt.Sscanf(f, "%X", &v)
				for _, u := range utf16.Encode([]rune{v}) {
					units = append(units, u)
					starts = append(starts, idx)
				}
				idx++
			}
			starts = append(starts, idx)
			if len(units) == 0 {
				fmt.Fprintln(w)
				continue
			}
			var err C.int32_t
			bi := C.ubrk_open_78(2, nil, (*C.uint16_t)(unsafe.Pointer(&units[0])), C.int32_t(len(units)), &err)
			var parts []string
			for {
				p := int(C.ubrk_next_78(bi))
				if p < 0 {
					break
				}
				st := int(C.ubrk_getRuleStatus_78(bi))
				mark := ""
				if st >= 100 && st < 200 {
					mark = "m"
				}
				parts = append(parts, fmt.Sprintf("%d%s", starts[p], mark))
			}
			C.ubrk_close_78(bi)
			fmt.Fprintln(w, strings.Join(parts, " "))
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
