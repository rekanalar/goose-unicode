# goose-unicode

[![ci](https://github.com/rekanalar/goose-unicode/actions/workflows/ci.yml/badge.svg)](https://github.com/rekanalar/goose-unicode/actions/workflows/ci.yml)

Unicode text handling for the [Goose](https://github.com/aardappel/goose)
programming language.

The package validates UTF-8 and names the byte offset of the first
malformed byte. It converts text to the four normalization forms. It
converts case and folds case for caseless compare. It gives the general
category and the combining class of a code point. It splits text into
grapheme clusters, words and sentences. Pure Goose, no C.

The package also gives the script, the width and the class of a code
point. It gives the mirror flag, the numeric value and the name too.
The name holds for every code point that the standard names.

The tables hold Unicode 17.0.0.

## Install

Add this to the root file of the program that uses it:

```goose
import unicode from "rekanalar/goose-unicode@v0.3.0";
```

## API

| Function | What it does |
|---|---|
| `utf8_valid(s)` | true when every byte of the text starts a sequence that the standard accepts |
| `utf8_decode(out, s)` | copies the code points into the buffer of the caller; gives the code and the offset of the first bad byte |
| `utf8_encode(out, cp)` | writes the UTF-8 form of one code point; refuses a surrogate and a value above U+10FFFF |
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
| `bidi_class(cp)` | the bidirectional class of a code point, as a `BIDI_` constant |
| `bidi_class_name(cp)` | the name of the class, such as `L` or `AL` |
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
when the call succeeds. A fault leaves the buffer empty.

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
- The `bidi_class` call gives the class of one code point. The package does
  not reorder a text by the bidirectional algorithm. Python has no such
  call in the standard library. Go holds the algorithm in
  `golang.org/x/text/unicode/bidi`. Rust holds the `unicode-bidi` crate.
- The package reads UTF-8 only. It does not read UTF-16 or UTF-32. Go holds
  `unicode/utf16` and `unicode/utf32`. Rust holds the `encoding` crates.
- The package does not give the width of the text for a terminal. The East
  Asian width is not a terminal width. Rust holds the `unicode-width`
  crate. Go holds `golang.org/x/text/width`.
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
  `ERR_TOO_LONG` and no work starts.
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
  values above U+10FFFF. The standard library walk of Goose gives the
  replacement character U+FFFD for a bad byte. It cannot report the
  fault. A program that stores the replacement character loses the
  difference between a bad byte and a real U+FFFD.
- The word and sentence splits take linear time. A long run of marks
  after an apostrophe runs in one pass. A long run of terminators runs in
  one pass. A long run of regional indicators runs in one pass. The test
  suite runs texts of 200,000 code points through each.
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
```

The scripts under `test/` build the tables of the package. They read the
files of the Unicode Character Database 17.0.0 and write numbers only.
Each script checks its table against a second source and fails on a
difference. The sources are the Go standard library and the packages of
`golang.org/x/text`. They are also the ICU library, Node with ICU 78 and
Python.

The scripts need the files of the Character Database. The first argument
of each script names the directory that holds them. The default is the
directory `tmp/ucd` of the management repository. The files come from
`https://www.unicode.org/Public/17.0.0/ucd/`. The word and sentence break files sit in its `auxiliary` directory. The script `test/NOTICE`
names the files and the license.

```bash
cd test
python3 make_unicode_data.py
python3 make_normalize_data.py
python3 make_grapheme_data.py
python3 make_vectors.py
python3 make_props_data.py
python3 make_case_full_data.py
python3 make_segment_data.py
```

## License

MIT
