// The oracle for the table generators. It prints properties that the
// Go standard library, golang.org/x/text and the ICU library hold. Each
// mode prints plain text that the generators compare with their own
// tables.
package main

/*
#cgo LDFLAGS: -l:libicuuc.so.79 -l:libicui18n.so.79
#include <stdint.h>
#include <stdlib.h>
int32_t u_charMirror_79(int32_t c);
double u_getNumericValue_79(int32_t c);
int32_t u_charName_79(int32_t codepoint, int32_t nameChoice, char* buffer, int32_t bufferLength, int32_t* err);
int32_t u_charDirection_79(int32_t c);
int32_t u_strToTitle_79(uint16_t* dest, int32_t destCapacity, const uint16_t* src, int32_t srcLength, void* titleIter, const char* locale, int32_t* err);
void* ubrk_open_79(int32_t type, const char* locale, const uint16_t* text, int32_t textLength, int32_t* status);
int32_t ubrk_next_79(void* bi);
int32_t ubrk_getRuleStatus_79(void* bi);
void ubrk_close_79(void* bi);
int32_t u_charFromName_79(int32_t nameChoice, const char* name, int32_t* err);
int32_t u_getIntPropertyValue_79(int32_t c, int32_t which);
const char* u_getPropertyValueName_79(int32_t property, int32_t value, int32_t nameChoice);
int32_t u_getBidiPairedBracket_79(int32_t c);
int32_t u_charDigitValue_79(int32_t c);
int32_t uscript_getScriptExtensions_79(int32_t c, int32_t* scripts, int32_t capacity, int32_t* err);
const char* uscript_getName_79(int32_t code);
void u_charAge_79(int32_t c, uint8_t* versionArray);
void u_getUnicodeVersion_79(uint8_t* versionArray);
int32_t u_toupper_79(int32_t c);
int32_t u_strToUpper_79(uint16_t* dest, int32_t destCapacity, const uint16_t* src, int32_t srcLength, const char* locale, int32_t* err);
int32_t u_strToLower_79(uint16_t* dest, int32_t destCapacity, const uint16_t* src, int32_t srcLength, const char* locale, int32_t* err);
int32_t u_tolower_79(int32_t c);
typedef struct UNormalizer2 UNormalizer2;
const UNormalizer2* unorm2_getNFCInstance_79(int32_t* err);
const UNormalizer2* unorm2_getNFDInstance_79(int32_t* err);
const UNormalizer2* unorm2_getNFKCInstance_79(int32_t* err);
const UNormalizer2* unorm2_getNFKDInstance_79(int32_t* err);
const UNormalizer2* unorm2_getNFKCCasefoldInstance_79(int32_t* err);
int32_t unorm2_normalize_79(const UNormalizer2* n2, const uint16_t* src, int32_t len, uint16_t* dest, int32_t cap, int32_t* err);
typedef void USpoofChecker;
USpoofChecker* uspoof_open_79(int32_t* err);
int32_t uspoof_getSkeleton_79(const USpoofChecker* sc, uint32_t type, const uint16_t* id, int32_t len, uint16_t* dest, int32_t cap, int32_t* err);
void uspoof_close_79(USpoofChecker* sc);
int32_t u_getPropertyEnum_79(const char* alias);
int8_t u_hasBinaryProperty_79(int32_t c, int32_t which);
void* ucol_open_79(const char* loc, int32_t* err);
void ucol_close_79(void* col);
int32_t ucol_strcoll_79(void* col, const uint16_t* a, int32_t alen, const uint16_t* b, int32_t blen);
int32_t ucol_getSortKey_79(void* col, const uint16_t* src, int32_t len, uint8_t* key, int32_t cap);
void* ucnv_open_79(const char* name, int32_t* err);
void ucnv_close_79(void* cnv);
int32_t ucnv_toUChars_79(void* cnv, uint16_t* dest, int32_t destCap, const char* src, int32_t srcLen, int32_t* err);
const char* ucnv_detectUnicodeSignature_79(const char* source, int32_t len, int32_t* sigLen, int32_t* err);
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
	case "icuver":
		// The Unicode release that the ICU library holds.
		var v [4]C.uint8_t
		C.u_getUnicodeVersion_79(&v[0])
		fmt.Printf("%d.%d.%d\n", v[0], v[1], v[2])
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
	case "icent":
		// As the nt mode, with the ICU library: five columns of code
		// points in hex, separated by bars, and the four forms of each.
		sc := bufio.NewScanner(os.Stdin)
		sc.Buffer(make([]byte, 1<<20), 1<<20)
		var e C.int32_t
		insts := []*C.UNormalizer2{
			C.unorm2_getNFCInstance_79(&e), C.unorm2_getNFDInstance_79(&e),
			C.unorm2_getNFKCInstance_79(&e), C.unorm2_getNFKDInstance_79(&e),
		}
		for sc.Scan() {
			var outs []string
			for _, col := range strings.Split(sc.Text(), "|") {
				var rs []rune
				for _, h := range strings.Fields(col) {
					var r rune
					fmt.Sscanf(h, "%X", &r)
					rs = append(rs, r)
				}
				src := utf16.Encode(rs)
				for _, in := range insts {
					dest := make([]uint16, 4*len(src)+64)
					var err C.int32_t
					var sp *C.uint16_t
					if len(src) > 0 {
						sp = (*C.uint16_t)(unsafe.Pointer(&src[0]))
					}
					n := C.unorm2_normalize_79(in, sp, C.int32_t(len(src)),
						(*C.uint16_t)(unsafe.Pointer(&dest[0])), C.int32_t(len(dest)), &err)
					if err != 0 {
						outs = append(outs, "error")
						continue
					}
					outs = append(outs, hexes(string(utf16.Decode(dest[:int(n)]))))
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
			return dirs[C.u_charDirection_79(C.int32_t(r))]
		}, func(v string) bool { return false }, true)
	case "mirror":
		for r := rune(0); r <= 0x10FFFF; r++ {
			m := C.u_charMirror_79(C.int32_t(r))
			if int32(m) != int32(r) {
				fmt.Fprintf(w, "%04X %04X\n", int(r), int(m))
			}
		}
	case "numeric":
		// ICU gives this value when the code point has no numeric value.
		const none = -1.23456789e+08
		for r := rune(0); r <= 0x10FFFF; r++ {
			d := float64(C.u_getNumericValue_79(C.int32_t(r)))
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
	case "icefullcase":
		// Each input line holds one code point in hex. The output holds
		// the full upper case and the full lower case of it from the ICU
		// library, separated by a tab, as the fullcase mode does.
		sc := bufio.NewScanner(os.Stdin)
		sc.Buffer(make([]byte, 1<<20), 1<<20)
		root := C.CString("")
		defer C.free(unsafe.Pointer(root))
		conv := func(r rune, f func(*C.uint16_t, C.int32_t, *C.uint16_t, C.int32_t, *C.char, *C.int32_t) C.int32_t) string {
			src := utf16.Encode([]rune{r})
			dest := make([]uint16, 64)
			var err C.int32_t
			n := f((*C.uint16_t)(unsafe.Pointer(&dest[0])), C.int32_t(len(dest)),
				(*C.uint16_t)(unsafe.Pointer(&src[0])), C.int32_t(len(src)), root, &err)
			if err != 0 {
				return "error"
			}
			return hexes(string(utf16.Decode(dest[:int(n)])))
		}
		for sc.Scan() {
			var r rune
			fmt.Sscanf(sc.Text(), "%X", &r)
			fmt.Fprintf(w, "%s\t%s\n",
				conv(r, func(d *C.uint16_t, dc C.int32_t, s *C.uint16_t, sl C.int32_t, l *C.char, e *C.int32_t) C.int32_t {
					return C.u_strToUpper_79(d, dc, s, sl, l, e)
				}),
				conv(r, func(d *C.uint16_t, dc C.int32_t, s *C.uint16_t, sl C.int32_t, l *C.char, e *C.int32_t) C.int32_t {
					return C.u_strToLower_79(d, dc, s, sl, l, e)
				}))
		}
	case "icetitle":
		// Each input line holds the code points of one text in hex,
		// separated by spaces. The output holds the title case of the
		// text from the ICU library.
		sc := bufio.NewScanner(os.Stdin)
		sc.Buffer(make([]byte, 1<<20), 1<<20)
		for sc.Scan() {
			fields := strings.Fields(sc.Text())
			rs := make([]rune, 0, len(fields))
			for _, f := range fields {
				var v rune
				fmt.Sscanf(f, "%X", &v)
				rs = append(rs, v)
			}
			src := utf16.Encode(rs)
			dest := make([]uint16, 4*len(src)+16)
			var err C.int32_t
			n := C.u_strToTitle_79((*C.uint16_t)(unsafe.Pointer(&dest[0])),
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
	case "icetitlecp":
		// The title case of every code point from the ICU library, as the
		// lines of the titlecp mode: the code points whose title case
		// differs from the code point.
		for r := rune(0); r <= 0x10FFFF; r++ {
			if isSurrogate(r) {
				continue
			}
			src := utf16.Encode([]rune{r})
			dest := make([]uint16, 64)
			var err C.int32_t
			n := C.u_strToTitle_79((*C.uint16_t)(unsafe.Pointer(&dest[0])),
				C.int32_t(len(dest)), (*C.uint16_t)(unsafe.Pointer(&src[0])),
				C.int32_t(len(src)), nil, nil, &err)
			if err != 0 {
				fmt.Fprintf(w, "%04X error\n", r)
				continue
			}
			out := string(utf16.Decode(dest[:int(n)]))
			if out != string(r) {
				fmt.Fprintf(w, "%04X %s\n", r, hexes(out))
			}
		}
	case "icelocale", "golocale":
		// Arguments: a locale tag and one of upper, lower, title. Each
		// input line holds the code points of one text in hex, separated
		// by spaces. The output holds the converted text in the same
		// form, from the ICU library or from golang.org/x/text.
		tag, kind := os.Args[2], os.Args[3]
		loc := C.CString(tag)
		defer C.free(unsafe.Pointer(loc))
		var gc cases.Caser
		switch kind {
		case "upper":
			gc = cases.Upper(language.Make(tag))
		case "lower":
			gc = cases.Lower(language.Make(tag))
		default:
			gc = cases.Title(language.Make(tag))
		}
		sc := bufio.NewScanner(os.Stdin)
		sc.Buffer(make([]byte, 1<<20), 1<<20)
		for sc.Scan() {
			var rs []rune
			for _, f := range strings.Fields(sc.Text()) {
				var v rune
				fmt.Sscanf(f, "%X", &v)
				rs = append(rs, v)
			}
			if os.Args[1] == "golocale" {
				fmt.Fprintf(w, "%s\n", hexes(gc.String(string(rs))))
				continue
			}
			src := utf16.Encode(rs)
			dest := make([]uint16, 4*len(src)+16)
			var err C.int32_t
			var n C.int32_t
			d, sp := (*C.uint16_t)(unsafe.Pointer(&dest[0])), (*C.uint16_t)(unsafe.Pointer(&src[0]))
			switch kind {
			case "upper":
				n = C.u_strToUpper_79(d, C.int32_t(len(dest)), sp, C.int32_t(len(src)), loc, &err)
			case "lower":
				n = C.u_strToLower_79(d, C.int32_t(len(dest)), sp, C.int32_t(len(src)), loc, &err)
			default:
				n = C.u_strToTitle_79(d, C.int32_t(len(dest)), sp, C.int32_t(len(src)), nil, loc, &err)
			}
			if err > 0 {
				fmt.Fprintf(w, "error %d\n", int(err))
				continue
			}
			fmt.Fprintf(w, "%s\n", hexes(string(utf16.Decode(dest[:int(n)]))))
		}
	case "icubrk":
		// The word boundaries of one text for one locale. The argument is
		// the locale. Each input line holds the code points of one text
		// in hex, separated by spaces. The output holds the offsets of
		// the boundaries from the ICU library, in UTF-16 units, each with
		// the rule status of the segment that it ends.
		breakLines(w, 1, os.Args[2], true)
	case "iculinebrk":
		// The line break opportunities of one text for one locale. The argument is
		// the locale. Each input line holds the code points of one text
		// in hex, separated by spaces. The output holds the offsets of
		// the boundaries from the ICU library, in UTF-16 units, each with
		// the rule status of the segment that it ends.
		breakLines(w, 2, os.Args[2], true)
	case "icuconv":
		// The lossy decode of the ICU converter of the given name, such as
		// UTF-8 or UTF-16LE. Each input line holds hex bytes. The output
		// holds the code points that ICU writes, with U+FFFD for each
		// bad part.
		name := C.CString(os.Args[2])
		defer C.free(unsafe.Pointer(name))
		sc := bufio.NewScanner(os.Stdin)
		sc.Buffer(make([]byte, 1<<22), 1<<22)
		for sc.Scan() {
			var bs []byte
			for _, f := range strings.Fields(sc.Text()) {
				var v int
				fmt.Sscanf(f, "%X", &v)
				bs = append(bs, byte(v))
			}
			bs = append(bs, 0)
			dest := make([]uint16, len(bs)+8)
			var err C.int32_t
			cv := C.ucnv_open_79(name, &err)
			if cv == nil {
				fmt.Fprintf(w, "error %d\n", int(err))
				continue
			}
			n := C.ucnv_toUChars_79(cv, (*C.uint16_t)(unsafe.Pointer(&dest[0])), C.int32_t(len(dest)), (*C.char)(unsafe.Pointer(&bs[0])), C.int32_t(len(bs)-1), &err)
			C.ucnv_close_79(cv)
			var out []string
			for _, r := range utf16.Decode(dest[:int(n)]) {
				out = append(out, fmt.Sprintf("%X", r))
			}
			fmt.Fprintf(w, "%s\n", strings.Join(out, " "))
		}
	case "icubom":
		// The converter name and the length of the byte order mark that
		// ICU detects. Each input line holds hex bytes. The output is the
		// name and the length, or none and 0.
		sc := bufio.NewScanner(os.Stdin)
		sc.Buffer(make([]byte, 1<<20), 1<<20)
		for sc.Scan() {
			var bs []byte
			for _, f := range strings.Fields(sc.Text()) {
				var v int
				fmt.Sscanf(f, "%X", &v)
				bs = append(bs, byte(v))
			}
			bs = append(bs, 0)
			var err, sig C.int32_t
			p := C.ucnv_detectUnicodeSignature_79((*C.char)(unsafe.Pointer(&bs[0])), C.int32_t(len(bs)-1), &sig, &err)
			if p == nil {
				fmt.Fprintf(w, "none 0\n")
			} else {
				fmt.Fprintf(w, "%s %d\n", C.GoString(p), int(sig))
			}
		}
	case "icusent":
		// The sentence boundaries of one text for one locale. The argument
		// is the locale. Each input line holds the code points of one text
		// in hex, separated by spaces. The output holds the offsets of the
		// boundaries from the ICU library, in UTF-16 units.
		breakLines(w, 3, os.Args[2], false)
	case "icuprop":
		// The runs of the value of one ICU integer property, as the long
		// name of the value. The argument is the number of the property.
		var prop int
		fmt.Sscanf(os.Args[2], "%d", &prop)
		runs(func(r rune) string {
			v := C.u_getIntPropertyValue_79(C.int32_t(r), C.int32_t(prop))
			p := C.u_getPropertyValueName_79(C.int32_t(prop), v, 1)
			if p == nil {
				return fmt.Sprintf("#%d", int(v))
			}
			return C.GoString(p)
		}, func(v string) bool { return false }, true)
	case "icushort":
		// The runs of the value of one ICU integer property, as the short
		// name of the value. The argument is the number of the property.
		var prop int
		fmt.Sscanf(os.Args[2], "%d", &prop)
		runs(func(r rune) string {
			v := C.u_getIntPropertyValue_79(C.int32_t(r), C.int32_t(prop))
			p := C.u_getPropertyValueName_79(C.int32_t(prop), v, 0)
			if p == nil {
				return fmt.Sprintf("#%d", int(v))
			}
			return C.GoString(p)
		}, func(v string) bool { return false }, true)
	case "icunum":
		// The runs of the number of one ICU integer property. The
		// argument is the number of the property.
		var prop int
		fmt.Sscanf(os.Args[2], "%d", &prop)
		runs(func(r rune) string {
			return fmt.Sprintf("%d", int(C.u_getIntPropertyValue_79(C.int32_t(r), C.int32_t(prop))))
		}, func(v string) bool { return false }, true)
	case "icucat":
		// The runs of the general category of the ICU library, as the
		// two letter name.
		runs(func(r rune) string {
			v := C.u_getIntPropertyValue_79(C.int32_t(r), 0x1005)
			return C.GoString(C.u_getPropertyValueName_79(0x1005, v, 0))
		}, func(v string) bool { return false }, true)
	case "icuwb":
		// The word break class of the ICU library, one code point per
		// line, with the name of the class.
		for r := rune(0); r <= 0x10FFFF; r++ {
			v := C.u_getIntPropertyValue_79(C.int32_t(r), 0x1014)
			fmt.Fprintf(w, "%04X %s\n", r, C.GoString(C.u_getPropertyValueName_79(0x1014, v, 0)))
		}
	case "iculb":
		// The line break class of the ICU library, one code point per
		// line, with the name of the class.
		for r := rune(0); r <= 0x10FFFF; r++ {
			v := C.u_getIntPropertyValue_79(C.int32_t(r), 0x1008)
			fmt.Fprintf(w, "%04X %s\n", r, C.GoString(C.u_getPropertyValueName_79(0x1008, v, 0)))
		}
	case "icucase":
		// The simple case mappings of the ICU library. The mode names
		// upper or lower. Each line holds a code point and its mapping.
		for r := rune(0); r <= 0x10FFFF; r++ {
			var m C.int32_t
			if os.Args[2] == "upper" {
				m = C.u_toupper_79(C.int32_t(r))
			} else {
				m = C.u_tolower_79(C.int32_t(r))
			}
			if int32(m) != int32(r) {
				fmt.Fprintf(w, "%04X %04X\n", int(r), int(m))
			}
		}
	case "icubracket":
		// The code points that have a paired bracket other than themselves.
		for r := rune(0); r <= 0x10FFFF; r++ {
			m := C.u_getBidiPairedBracket_79(C.int32_t(r))
			if int32(m) != int32(r) {
				fmt.Fprintf(w, "%04X %04X\n", int(r), int(m))
			}
		}
	case "icudigit":
		// The decimal digit value of every code point that has one.
		for r := rune(0); r <= 0x10FFFF; r++ {
			d := C.u_charDigitValue_79(C.int32_t(r))
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
			n := int(C.uscript_getScriptExtensions_79(C.int32_t(r), &sc[0], 64, &err))
			names := make([]string, 0, n)
			for k := 0; k < n; k++ {
				names = append(names, C.GoString(C.uscript_getName_79(sc[k])))
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
		col := C.ucol_open_79(loc, &st)
		C.free(unsafe.Pointer(loc))
		if st != 0 {
			fmt.Fprintln(w, "open error")
			break
		}
		defer C.ucol_close_79(col)
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
				n := C.ucol_getSortKey_79(col, (*C.uint16_t)(unsafe.Pointer(&ua[0])),
					C.int32_t(len(ua)), &buf[0], C.int32_t(len(buf)))
				parts := make([]string, n)
				for i := 0; i < int(n); i++ {
					parts[i] = fmt.Sprintf("%02X", buf[i])
				}
				fmt.Fprintln(w, strings.Join(parts, " "))
				continue
			}
			ub := sign(second)
			fmt.Fprintln(w, C.ucol_strcoll_79(col, (*C.uint16_t)(unsafe.Pointer(&ua[0])),
				C.int32_t(len(ua)), (*C.uint16_t)(unsafe.Pointer(&ub[0])), C.int32_t(len(ub))))
		}
	case "icebin":
		// The runs of one binary property from the ICU library. The
		// argument is the name of the property. ICU gives -1 for a
		// name it does not know, and the mode prints "unknown".
		cname := C.CString(os.Args[2])
		prop := C.u_getPropertyEnum_79(cname)
		C.free(unsafe.Pointer(cname))
		if prop < 0 {
			fmt.Fprintln(w, "unknown")
			break
		}
		w.Flush()
		runs(func(r rune) string {
			if C.u_hasBinaryProperty_79(C.int32_t(r), prop) != 0 {
				return "Y"
			}
			return "N"
		}, func(v string) bool { return v == "N" }, true)
	case "iceskel":
		// Each input line holds the code points of one text in hex.
		// The output holds the code points of the skeleton of the text
		// from the ICU 78 library.
		var st C.int32_t
		sc := C.uspoof_open_79(&st)
		if st != 0 {
			fmt.Fprintln(w, "open error")
			break
		}
		defer C.uspoof_close_79(sc)
		lines := bufio.NewScanner(os.Stdin)
		lines.Buffer(make([]byte, 1<<20), 1<<20)
		w.Flush()
		for lines.Scan() {
			var units []uint16
			for _, f := range strings.Fields(lines.Text()) {
				var v rune
				fmt.Sscanf(f, "%X", &v)
				for _, u := range utf16.Encode([]rune{v}) {
					units = append(units, u)
				}
			}
			dest := make([]uint16, 4*len(units)+64)
			err := C.int32_t(0)
			n := C.uspoof_getSkeleton_79(sc, 0, (*C.uint16_t)(unsafe.Pointer(&units[0])),
				C.int32_t(len(units)), (*C.uint16_t)(unsafe.Pointer(&dest[0])),
				C.int32_t(len(dest)), &err)
			if err != 0 {
				fmt.Fprintln(w, "error")
				continue
			}
			out := make([]rune, 0, n)
			for i := 0; i < int(n); i++ {
				out = append(out, rune(dest[i]))
			}
			fmt.Fprintln(w, hexes(string(out)))
		}
	case "icefold":
		// Each input line holds the code points of one text in hex.
		// The output holds the code points of the NFKC case fold of
		// the text from the ICU 78 library.
		var st C.int32_t
		n2 := C.unorm2_getNFKCCasefoldInstance_79(&st)
		if st != 0 {
			fmt.Fprintln(w, "open error")
			break
		}
		sc := bufio.NewScanner(os.Stdin)
		sc.Buffer(make([]byte, 1<<20), 1<<20)
		w.Flush()
		for sc.Scan() {
			var units []uint16
			for _, f := range strings.Fields(sc.Text()) {
				var v rune
				fmt.Sscanf(f, "%X", &v)
				for _, u := range utf16.Encode([]rune{v}) {
					units = append(units, u)
				}
			}
			dest := make([]uint16, 4*len(units)+64)
			err := C.int32_t(0)
			n := C.unorm2_normalize_79(n2, (*C.uint16_t)(unsafe.Pointer(&units[0])),
				C.int32_t(len(units)), (*C.uint16_t)(unsafe.Pointer(&dest[0])),
				C.int32_t(len(dest)), &err)
			if err != 0 {
				fmt.Fprintln(w, "error")
				continue
			}
			out := make([]rune, 0, n)
			for i := 0; i < int(n); i++ {
				out = append(out, rune(dest[i]))
			}
			fmt.Fprintln(w, hexes(string(out)))
		}
	case "goprop":
		// The runs of one property of the unicode.Properties table of
		// the Go standard library. The argument is the name. The mode
		// prints "unknown" when the table has no such name.
		tab, ok := unicode.Properties[os.Args[2]]
		if !ok {
			fmt.Fprintln(w, "unknown")
			break
		}
		w.Flush()
		runs(func(r rune) string {
			if unicode.Is(tab, r) {
				return "Y"
			}
			return "N"
		}, func(v string) bool { return v == "N" }, true)
	case "iceage":
		// The runs of the age of every code point, as major.minor.
		runs(func(r rune) string {
			var v [4]C.uint8_t
			C.u_charAge_79(C.int32_t(r), &v[0])
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
				r := C.u_charFromName_79(choice, cn, &err)
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
			bi := C.ubrk_open_79(2, nil, (*C.uint16_t)(unsafe.Pointer(&units[0])), C.int32_t(len(units)), &err)
			var parts []string
			for {
				p := int(C.ubrk_next_79(bi))
				if p < 0 {
					break
				}
				st := int(C.ubrk_getRuleStatus_79(bi))
				mark := ""
				if st >= 100 && st < 200 {
					mark = "m"
				}
				parts = append(parts, fmt.Sprintf("%d%s", starts[p], mark))
			}
			C.ubrk_close_79(bi)
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
// The boundaries of one text for one locale, from the ICU break
// iterator. The kind is the type of the iterator: 1 for the word, 2 for
// the line and 3 for the sentence. Each input line holds the code
// points of one text in hex, separated by spaces. The output holds the
// offsets of the boundaries in UTF-16 units. Each offset holds the rule
// status of the segment that it ends, when the status is asked for.
func breakLines(w *bufio.Writer, kind int, locale string, withStatus bool) {
	tag := C.CString(locale)
	defer C.free(unsafe.Pointer(tag))
	sc := bufio.NewScanner(os.Stdin)
	sc.Buffer(make([]byte, 1<<20), 1<<20)
	for sc.Scan() {
		var rs []rune
		for _, f := range strings.Fields(sc.Text()) {
			var v rune
			fmt.Sscanf(f, "%X", &v)
			rs = append(rs, v)
		}
		units := utf16.Encode(rs)
		var err C.int32_t
		bi := C.ubrk_open_79(C.int32_t(kind), tag, (*C.uint16_t)(unsafe.Pointer(&units[0])), C.int32_t(len(units)), &err)
		if bi == nil {
			fmt.Fprintf(w, "error %d\n", int(err))
			continue
		}
		var out []string
		for {
			p := int(C.ubrk_next_79(bi))
			if p < 0 {
				break
			}
			if withStatus {
				out = append(out, fmt.Sprintf("%d:%d", p, int(C.ubrk_getRuleStatus_79(bi))))
			} else {
				out = append(out, fmt.Sprintf("%d", p))
			}
		}
		fmt.Fprintf(w, "%s\n", strings.Join(out, " "))
		C.ubrk_close_79(bi)
	}
}

func u_charName(r int) string {
	var err C.int32_t
	buf := make([]byte, 128)
	C.u_charName_79(C.int32_t(r), 0, (*C.char)(unsafe.Pointer(&buf[0])), C.int32_t(len(buf)), &err)
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
