# goose-unicode

[![ci](https://github.com/rekanalar/goose-unicode/actions/workflows/ci.yml/badge.svg)](https://github.com/rekanalar/goose-unicode/actions/workflows/ci.yml)

Unicode text handling for the [Goose](https://github.com/aardappel/goose)
programming language.

The package validates UTF-8 and names the byte offset of the first
malformed byte. It converts text to the four normalization forms. It
converts case and folds case for caseless compare. It gives the general
category and the combining class of a code point. It splits text into
grapheme clusters, words and sentences. It reads and writes UTF-16 and
UTF-32.

Pure Goose, no C.

The package gives the width of a character and of a text in terminal
columns. It runs the bidirectional algorithm and gives the levels and the
visual order of a text.

The package also gives the script, the width and the class of a code
point. It gives the mirror flag, the numeric value and the name too.
The name holds for every code point that the standard names.

The tables hold Unicode 17.0.0.

## Install

Add this to the root file of the program that uses it:

```goose
import unicode from "rekanalar/goose-unicode@v0.8.0";
```

## API

| Function | What it does |
|---|---|
| `utf8_valid(s)` | true when every byte of the text starts a sequence that the standard accepts |
| `utf8_decode(out, s)` | copies the code points into the buffer of the caller; gives the code and the offset of the first bad byte |
| `utf8_encode(out, cp)` | writes the UTF-8 form of one code point; refuses a surrogate and a value above U+10FFFF |
| `utf16_decode(out, s, big_endian)` | reads the UTF-16 bytes of the text and writes the code points into the buffer of the caller; gives the code and the offset of the first bad byte |
| `utf16_encode(out, cps, big_endian)` | writes the UTF-16 bytes of the code points into the buffer of the caller |
| `utf16_rune_len(cp)` | the number of UTF-16 units of the code point: 1, 2 or 0 |
| `utf16_is_surrogate(cp)` | true when the code point is in the range U+D800 to U+DFFF |
| `utf32_decode(out, s, big_endian)` | reads the UTF-32 bytes of the text and writes the code points into the buffer of the caller; gives the code and the offset of the first bad byte |
| `utf32_encode(out, cps, big_endian)` | writes the UTF-32 bytes of the code points into the buffer of the caller |
| `utf32_rune_len(cp)` | 1 for a code point that UTF-32 can hold, 0 for the rest |
| `normalize(out, form, s)` | writes the text in the given form into the buffer of the caller |
| `is_normalized(form, s)` | true when the text is already in the given form |
| `to_upper(out, s)` | writes the text in upper case with the simple mappings |
| `to_lower(out, s)` | writes the text in lower case with the simple mappings |
| `fold_case(out, s)` | writes the text in its case fold, for caseless compare |
| `to_upper_full(out, s)` | writes the text in upper case with the full mappings |
| `to_lower_full(out, s)` | writes the text in lower case with the full mappings and the final sigma |
| `category(cp)` | the general category of a code point, as a `CAT_` constant |
| `category_name(cp)` | the two letter name of the category, such as `Lu` |
| `combining_class(cp)` | the canonical combining class of a code point, from 0 to 240 |
| `script(cp)` | the script of a code point, as a `SCRIPT_` constant |
| `script_name(cp)` | the name of the script, such as `Latin` |
| `width(cp)` | the East Asian width of a code point, as a `WIDTH_` constant |
| `width_name(cp)` | the name of the width, such as `Wide` |
| `char_width(cp)` | the width of one code point in terminal columns: 0, 1, 2 or 3; a control character gives -1 |
| `string_width(s)` | the width of the text in terminal columns; gives a fault code and the width |
| `char_width_cjk(cp)` | the width of one code point in the East Asian context: an ambiguous character takes 2 columns |
| `string_width_cjk(s)` | the width of the text in the East Asian context; gives a fault code and the width |
| `bidi_class(cp)` | the bidirectional class of a code point, as a `BIDI_` constant |
| `bidi_class_name(cp)` | the name of the class, such as `L` or `AL` |
| `bidi_levels(out, s, dir)` | the embedding level of each code point; `dir` is `BIDI_DIR_LTR`, `BIDI_DIR_RTL` or `BIDI_DIR_AUTO`; gives a fault code and the level of the first paragraph |
| `bidi_order(out, levels)` | the visual order of a line: the index of each code point from left to right |
| `mirrored(cp)` | true when the code point is mirrored |
| `mirror_of(cp)` | the mirror partner of a code point; a code point that is not mirrored gives itself |
| `numeric_value(cp)` | the numeric value as the numerator and the denominator; a denominator of zero means no value |
| `name(cp)` | the name of a code point in the Character Database; no name gives the empty slice |
| `grapheme_count(s)` | the number of clusters that a user sees in the text |
| `grapheme_next(s, at)` | the end of the cluster that starts at the byte offset; gives the code and the end |
| `grapheme_offsets(out, s)` | copies the start offset of every cluster into the buffer of the caller |
| `word_next(s, at)` | the end of the word segment that starts at the byte offset; gives the code and the end |
| `word_count(s)` | the number of word segments, the spaces and the punctuation too |
| `word_offsets(out, s)` | copies the start offset of every word segment into the buffer of the caller |
| `is_word_like(s, start, end)` | true when the segment holds a letter, a number or an ideograph |
| `sentence_next(s, at)` | the end of the sentence that starts at the byte offset; gives the code and the end |
| `sentence_count(s)` | the number of sentences in the text |
| `sentence_offsets(out, s)` | copies the start offset of every sentence into the buffer of the caller |

The form is one of `FORM_NFC`, `FORM_NFD`, `FORM_NFKC` and `FORM_NFKD`. The
general category is one of `CAT_CN`, `CAT_LU`, `CAT_LL` and the other 26
constants of the package.

Every call that writes text clears the buffer of the caller first, except
`utf8_encode`, which appends. Every call that reads text gives a fault code
and the byte offset of the first malformed byte. The offset is minus one
when the call succeeds. A fault leaves the buffer empty. The
`string_width` call gives a fault code and no offset, because a caller of
the width needs the width only.

```goose
var out: u8[>..] = [];
let code, offset = unicode::normalize(out, unicode::FORM_NFC, "café");
if code == unicode::OK {
    print(out);   // café
}
```

## Normalizing

The package follows the Unicode normalization standard. It applies the
composition exclusions of the standard, so the sequences that the standard
names stay decomposed. It applies the blocked pair rule, so a mark between
two code points stops the composition of the pair.

The `is_normalized` call gives the same answer as the full conversion on
every input. It reads the quick check tables of the standard first. It
runs the full conversion when a table cannot decide.

## Case

The `to_upper` and `to_lower` calls use the simple one to one mappings of
Unicode. The result holds one code point for each code point of the input.
The `fold_case` call uses the full case folding table, where one code
point can give more than one code point.

```goose
var out: u8[>..] = [];
unicode::fold_case(out, "Straße");   // strasse
```

The `to_upper_full` and `to_lower_full` calls use the full mappings. The
German sharp s gives two letters. The rule of the final sigma holds in
the lower case. A sigma at the end of a word gives the final sigma. The
package applies no language specific rule. It gives no Turkish or
Lithuanian form.

```goose
var out: u8[>..] = [];
unicode::to_upper_full(out, "Straße");   // STRASSE
unicode::to_lower_full(out, "ΟΟΣ ΟΣ");   // οος ος
```

## UTF-16

The package reads and writes UTF-16 in both byte orders. The byte order
is the last argument of the two calls. A code point below U+10000 takes
one unit. A code point at or above U+10000 takes two units: a high
surrogate and a low surrogate.

A lone surrogate is a fault. The call gives `ERR_BAD_UTF16` and the
byte offset of the first bad byte. The buffer of the caller stays
empty. An odd count of bytes is a fault too.

The Go library writes U+FFFD for a lone surrogate, so the two answers
differ there. The Node library writes U+FFFD as well, unless the
decoder runs in the fatal mode. The Rust library refuses the text.

The package does not read the byte order mark. A caller that reads a
file with a mark removes the first two bytes itself.

```goose
var cps: i64[>..] = [];
unicode::utf8_decode(cps, "Hi");
var out: u8[>..] = [];
unicode::utf16_encode(out, cps[..], false);
print(out);   // H i
```

## UTF-32

The package reads and writes UTF-32 in both byte orders. The byte order
is the last argument of the two calls. Every code point takes one unit
of four bytes.

A surrogate and a value above U+10FFFF are faults. The call gives
`ERR_BAD_UTF32` and the byte offset of the first bad byte. The buffer of
the caller stays empty. A length that no count of units gives, such as
five bytes, is a fault too. The offset names the start of the short
unit.

The strict codecs of Python refuse a surrogate too. A plain slice of
`u32` in Rust holds no rule at all. Go holds no UTF-32 library and Node
rejects UTF-32, so the vectors of the test suite come from Python only.

The package does not read the byte order mark. A caller that reads a
file with a mark removes the first four bytes itself.

```goose
var cps: i64[>..] = [];
unicode::utf8_decode(cps, "Hi");
var out: u8[>..] = [];
unicode::utf32_encode(out, cps[..], false);
print(out);   // H i and two zero bytes
```

## Properties

The property calls take one code point. Each lookup is a binary search
over a table of the standard. A code point outside U+0000 to U+10FFFF
takes the default of the property. The default is the unknown script and
the neutral width. It is also the right to left class, no mirror flag, no
value and no name.

The name call also builds the names that the standard builds from a rule.
The CJK, Tangut, Nushu and Khitan ideograph names are the prefix and the
hex form. The Hangul syllable names come from the short names of the
three jamo.

```goose
print(unicode::script_name(0x6F22));   // Han
print(unicode::name(0xAC00));          // HANGUL SYLLABLE GA
let num, den = unicode::numeric_value(0xBD);
print(num, "/", den);                  // 1/2
```

## Grapheme clusters

The package splits text by the rules of the Unicode text segmentation
standard. A letter and a mark form one cluster. A flag of two regional
indicators forms one cluster. A family joined by zero width joiners forms
one cluster. A malformed byte forms a cluster of its own, and it never
merges with a neighbour.

```goose
let code, count = unicode::grapheme_count("a🇩🇪");
print(count);   // 2
```

## Words and sentences

The package splits text by the default word rules and the default sentence
rules of the Unicode text segmentation standard. The segments cover the
whole text, so the spaces and the punctuation are segments too. The
`is_word_like` call tells a word from the rest. A full stop inside a
number or a letter run does not end a word. A capital letter after a full
stop and a space starts a new sentence. A lower case letter does not.

```goose
let text = "Dr. Who said it's 3.14.";
let code, end = unicode::word_next(text, 4);
print(text[4..end]);   // Who
```

A malformed byte forms a segment of its own. The time of every call is
linear in the text. A call reads ahead past the marks that join to one
code point only. A sentence read stops at the next terminator.

## Bidirectional text

The `bidi_levels` call runs the Unicode bidirectional algorithm (UAX #9)
on a UTF-8 text. It gives one level per code point. An even level reads
left to right and an odd level reads right to left. The text splits into
paragraphs at each paragraph separator, and each paragraph takes its own
level. The call returns the level of the first paragraph too.

The code points that the algorithm removes get the level -1. These are
the embedding and override marks and the boundary neutrals. The depth
limit is 125, and the bracket stack holds 63 entries. The call applies the rules for
isolates, paired brackets and the trailing white space. It treats the
whole paragraph as one line.

The `bidi_order` call reverses the runs of a line by rule L2. It skips a
code point of level -1. A level below -1 or above 126 gives `ERR_BAD_ARG`.
The package leaves out the rules L3 and L4, which depend on the renderer.

```goose
var levels: i64[>..] = [];
let code, para = unicode::bidi_levels(levels, "ab אב", unicode::BIDI_DIR_AUTO);
var order: i64[>..] = [];
unicode::bidi_order(order, levels[..]);
```

The package agrees with every line of `BidiTest.txt` and
`BidiCharacterTest.txt` of Unicode 17.0.0. Python has no such call in the
standard library. Go holds `golang.org/x/text/unicode/bidi`, and Rust
holds `unicode-bidi`. Both give a result per line, and this package
gives the same levels for a line that spans the paragraph.

## Width

The package gives the width of a character and of a text in the columns
of a terminal. The rules follow the Rust `unicode-width` crate, the only
reference that documents a full rule set.

The `char_width` call gives 0 for a combining mark and 1 for a narrow
letter. It gives 2 for an ideograph and 3 for the Khmer sign U+17D8. A
control character takes -1. A surrogate takes -1, and so does a value
outside U+0000 to U+10FFFF. Python `wcwidth` gives -1 for a control
character as well. Node `string-width` gives 0 for one, so the two
answers differ there.

```goose
print(unicode::char_width(0x4E2D));   // 2
print(unicode::char_width(0x0300));   // 0
```

The `string_width` call walks the text from the end. It joins the
sequences that a terminal draws as one cell. A family of emoji joined by
zero width joiners counts as 2. A flag of two regional indicators counts
as 2. A base with U+FE0F counts as 2.

The call applies the script ligature rules of Rust. A Lam and an Alef
in Arabic count as one column. An Alef and a Lamed in Hebrew count as
one column. A coeng and a letter in Khmer count as one column less.
The rules join pairs in Buginese, Tifinagh, Lisu, Old Turkic and Kirat
Rai.

A base with U+FE0E counts as 1 when the base takes the emoji form by
default. The keycap of a digit counts as 2.

A control character counts as 1 in a text, and CR LF counts as 1.
Python `wcswidth` gives -1 for a text that holds a control character.
Node gives 0 to a control character.

```goose
let code, w = unicode::string_width("🇩🇪");
print(w);   // 2
```

The call gives `ERR_BAD_UTF8` on a bad byte, and `ERR_TOO_LONG` above
`MAX_INPUT`. It reads the bytes once, so the time is linear.

The `string_width_cjk` call gives the width in the East Asian context. An
ambiguous character takes 2 columns there, and 1 outside. A combining
long solidus overlay joins the sign that precedes it. The sign is a
less-than, an equals or a greater-than. The two form one glyph of 2
columns.

The narrow variation selectors U+FE00 and U+FE02 take the narrow form
there. U+FE01 takes it outside. The call gives the same fault codes as
`string_width`.

```goose
print(unicode::char_width(0xA1));        // 1
print(unicode::char_width_cjk(0xA1));    // 2
```

## Limits

- The word and sentence splits follow the default rules and no locale.
  Node `Intl.Segmenter` splits Chinese, Japanese, Thai, Lao, Khmer and
  Burmese with a dictionary, so it gives other words there. The default
  rules split every Han ideograph. They give no boundary inside a Thai
  run. Rust `unicode-segmentation` follows the default rules, as this
  package does. Python has no such call in the standard library.
- The sentence split holds no list of abbreviations. It splits "Mr. Smith"
  after "Mr.".
- The `is_word_like` call gives false for a text above `MAX_INPUT` and for
  a bad range. It has no fault code.
- The `is_word_like` flag follows the content of the segment. ICU takes
  the flag of Node from the last rule that built the segment. Node can
  differ for a segment that joins an apostrophe, a colon or a connector
  to other code points.
- The bidirectional calls treat a paragraph as one line. A caller that
  breaks a paragraph into lines passes the levels of each line to
  `bidi_order`. The rules L3 and L4 depend on the renderer, and the
  package leaves them out. So do the combining marks and the mirrored
  glyphs. The `mirrored` call gives the mirror flag of a code point.
- The package reads UTF-8, UTF-16 and UTF-32.
- The East Asian form skips the same marks as Rust after a combining
  solidus overlay. Rust reads one field of the Character Database
  loosely. It adds seven number signs, such as U+1011B, to the skipped
  marks. This package copies that result, so the two agree.
- The package holds no way to ask for both widths of one text at once.
  Rust holds the same two calls. Node, Go and Python hold one call
  with a flag.
- The package does not strip ANSI escape codes. Node `string-width`
  strips them. The width of an escape sequence here is the sum of the
  widths of its characters.
- Go holds `golang.org/x/text/width`, which gives the East Asian width
  class and no terminal width. The package gives the class with `width`
  and the columns with `string_width`.
- The package does not apply the identifier rules of a host language. The
  rules of a language depend on its own standard, not on Unicode alone.
- The package applies no language specific case rule, so it gives no
  Turkish dotless i and no Lithuanian dot above. Python and Node apply
  these rules only with a language tag too.
- The tables hold Unicode 17.0.0. Python `unicodedata` holds Unicode
  16.0.0, so it gives different answers for the code points that Unicode
  17 added. Node holds Unicode 17.0.0 through ICU 78. Go holds Unicode
  17.0.0 in the standard library and in `golang.org/x/text/unicode/norm`.
- The quick check tables come from the same version of the Character
  Database as the other tables. A later Unicode version can add a table
  entry and change the answer of `is_normalized` for a new code point.

## Security

The package parses text from people we do not know. These protections go
beyond the reference libraries.

- Every call checks the length of its input before any other work. The
  limit is `MAX_INPUT` of 1,048,576 bytes. A longer input gives
  `ERR_TOO_LONG` and no work starts. The UTF-16 and UTF-32 encoders
  count code points, not bytes, so they take at most 1,048,576 code
  points.
- Every call that writes text checks the length of its result. The limit is
  `MAX_OUTPUT` of 4,194,304 bytes. A longer result gives `ERR_TOO_LONG`
  and writes nothing. A compatibility decomposition of a long text can
  grow the text by a factor of 18. Python `unicodedata.normalize` and Go
  `norm` have no such limit.
- A fault holds a code and an offset. It never holds bytes of the input.
  The offset points at the first bad byte, and the caller holds the input.
  A fault leaves the output buffer empty.
- The sort of a run of combining marks uses a counting sort above 32
  marks. A hostile run of marks cannot take quadratic time. The insertion
  sort of the smaller runs keeps the order of equal classes.
- The decoder rejects overlong forms, surrogates, truncated sequences and
  values above U+10FFFF.
- The bidirectional algorithm reads the text a bounded number of times.
  The matching isolates hold a bounded number of entries. So do the
  first strong letter of each isolate, the bracket stack and the level
  runs. A hostile text of nested isolates cannot take quadratic time.
  A text of open brackets or of deep embeddings cannot exhaust the
  memory.
  The Go library and the Rust crate bound the same values.
- The width walk of a text holds one small state and reads the text from
  the end. The time is linear in the bytes. A hostile text of joiners,
  regional indicators or variation selectors cannot take quadratic time.
  The Rust library walks the text in the same way.

  The UTF-16 decoder refuses a lone surrogate too. The Go library writes
  U+FFFD for it. A file with a lone surrogate gives an error here and a
  text there. The standard library walk of Goose gives the
  replacement character U+FFFD for a bad byte. It cannot report the
  fault. A program that stores the replacement character loses the
  difference between a bad byte and a real U+FFFD.
- The word and sentence splits take linear time. A long run of marks
  after an apostrophe runs in one pass. A long run of terminators runs in
  one pass. A long run of regional indicators runs in one pass. The test
  suite runs texts of 200,000 code points through each.
- The width of a text takes one pass to decode and one pass to walk. The
  walk holds one integer of state. A hostile run of joiners, regional
  indicators or variation selectors cannot take quadratic time. The test
  suite runs texts of 1 MiB through each. Rust `unicode-width` has no
  input bound, but this package refuses a text above `MAX_INPUT`.
- Every property lookup is a binary search of bounded depth. A hostile
  code point cannot make a lookup take longer than the depth of the
  table. The test suite feeds 20,000 random code points around and
  beyond the range of each lookup.

These risks stay.

- The package does not sanitize the text. It gives the category of a code
  point so a caller can write its own rules. A program that writes the
  text into HTML must escape it itself.
- The package does not check the meaning of the text. A text that holds a
  control character is well formed UTF-8. The package reports it, and it
  leaves the choice to the caller.
- The tables come from the Unicode Character Database. The Unicode
  Consortium publishes the data files under the Unicode License. The
  license text is in `test/NOTICE`.

## Test

```bash
goose run test/run.goose
goose run examples/normalize.goose
goose run examples/grapheme.goose
goose run examples/case.goose
goose run examples/props.goose
goose run examples/words.goose
goose run examples/utf16.goose
goose run examples/utf32.goose
goose run examples/width.goose
```

The scripts under `test/` build the tables of the package. They read the
files of the Unicode Character Database 17.0.0 and write numbers only.
Each script checks its table against a second source and fails on a
difference. The sources are the Go standard library and the packages of
`golang.org/x/text`. They are also the ICU library, Node with ICU 78,
Python and the Rust `unicode-width` crate.

The width script checks every code point against the crate. It also
writes 50,040 texts of the sequence characters. Each text has the width
from the crate. The suite checks the package against it. The script
needs `cargo`. The build of the oracle reads the crate from the local cache:

```bash
cd test/oracle && cargo build --release --offline && cd ..
python3 make_width_data.py
```

The scripts need the files of the Character Database. The first argument
of each script names the directory that holds them. The default is the
directory `tmp/ucd` of the management repository. The files come from
`https://www.unicode.org/Public/17.0.0/ucd/`. The word and sentence break
files sit in its `auxiliary` directory. The general category file sits in
its `extracted` directory.

The file `test/NOTICE` names the files and the license.

```bash
cd test
python3 make_unicode_data.py
python3 make_normalize_data.py
python3 make_grapheme_data.py
python3 make_vectors.py
python3 make_props_data.py
python3 make_case_full_data.py
python3 make_segment_data.py
python3 make_utf16_data.py
python3 make_utf32_data.py
python3 make_width_data.py
```

## License

MIT
