# goose-unicode

[![ci](https://github.com/rekanalar/goose-unicode/actions/workflows/ci.yml/badge.svg)](https://github.com/rekanalar/goose-unicode/actions/workflows/ci.yml)

Unicode text handling for the [Goose](https://github.com/aardappel/goose)
programming language.

The package validates UTF-8 and names the byte offset of the first
malformed byte. It converts text to the four normalization forms. It
converts case and folds case for caseless compare. It gives the general
category and the combining class of a code point. It splits text into
grapheme clusters. Pure Goose, no C.

The tables hold Unicode 17.0.0.

## Install

Add this to the root file of the program that uses it:

```goose
import unicode from "rekanalar/goose-unicode@v0.1.0";
```

## API

| Function | What it does |
|---|---|
| `utf8_valid(s)` | true when every byte of the text starts a sequence that the standard accepts |
| `utf8_decode(out, s)` | copies the code points into the buffer of the caller; gives the code and the offset of the first bad byte |
| `utf8_encode(out, cp)` | writes the UTF-8 form of one code point; refuses a surrogate and a value above U+10FFFF |
| `normalize(out, form, s)` | writes the text in the given form into the buffer of the caller |
| `is_normalized(form, s)` | true when the text is already in the given form |
| `to_upper(out, s)` | writes the text in upper case |
| `to_lower(out, s)` | writes the text in lower case |
| `fold_case(out, s)` | writes the text in its case fold, for caseless compare |
| `category(cp)` | the general category of a code point, as a `CAT_` constant |
| `category_name(cp)` | the two letter name of the category, such as `Lu` |
| `combining_class(cp)` | the canonical combining class of a code point, from 0 to 240 |
| `grapheme_count(s)` | the number of clusters that a user sees in the text |
| `grapheme_next(s, at)` | the end of the cluster that starts at the byte offset; gives the code and the end |
| `grapheme_offsets(out, s)` | copies the start offset of every cluster into the buffer of the caller |

The form is one of `FORM_NFC`, `FORM_NFD`, `FORM_NFKC` and `FORM_NFKD`. The
general category is one of `CAT_CN`, `CAT_LU`, `CAT_LL` and the other 26
constants of the package.

Every call that writes text clears the buffer of the caller first, except `utf8_encode`, which appends. Every
call that reads text gives a fault code and the byte offset of the first
malformed byte. The offset is minus one when the call succeeds.

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

## Limits

- The package holds no scripts, no East Asian width and no character
  names. It holds no bidirectional classes, no mirrored flag and no
  numeric values. Python `unicodedata` gives the scripts, the width, the
  names, the classes, the flag and the numeric values. Node gives the
  scripts through the property escapes of a regular expression. Go holds
  the width in `golang.org/x/text/width` and the scripts in
  `golang.org/x/text`.
- The package does not split text into sentences or words. Node holds
  `Intl.Segmenter`. Rust holds the `unicode-segmentation` crate. Python has
  no such call in the standard library.
- The `to_upper` and `to_lower` calls use the simple mappings. They do not
  use the full mappings that depend on the text around a letter, such as
  the final sigma. Python `str.upper` and `str.lower` use the full
  mappings. The full mappings change the length of the text.
- The package reads UTF-8 only. It does not read UTF-16 or UTF-32. Go holds
  `unicode/utf16` and `unicode/utf32`. Rust holds the `encoding` crates.
- The package does not give the width of the text for a terminal. Rust
  holds the `unicode-width` crate. Go holds `golang.org/x/text/width`.
- The package does not apply the identifier rules of a host language. The
  rules of a language depend on its own standard, not on Unicode alone.
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
- The sort of a run of combining marks uses a counting sort above 32
  marks. A hostile run of marks cannot take quadratic time. The insertion
  sort of the smaller runs keeps the order of equal classes.
- The decoder rejects overlong forms, surrogates, truncated sequences and
  values above U+10FFFF. The standard library walk of Goose gives the
  replacement character U+FFFD for a bad byte. It cannot report the
  fault. A program that stores the replacement character loses the
  difference between a bad byte and a real U+FFFD.

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
```

The scripts under `test/` build the tables of the package. They read the
files of the Unicode Character Database 17.0.0 and write numbers only.
Each script checks its table against a second source and fails on a
difference. The second source is the Go standard library, the Go package
`golang.org/x/text/unicode/norm` and Node with ICU 78.

The scripts need the files of the Character Database. The first argument
of each script names the directory that holds them. The default is the
directory `tmp/ucd` of the management repository. The files come from
`https://www.unicode.org/Public/17.0.0/ucd/`. The script `test/NOTICE`
names the files and the license.

```bash
cd test
python3 make_unicode_data.py
python3 make_normalize_data.py
python3 make_grapheme_data.py
python3 make_vectors.py
```

## License

MIT
