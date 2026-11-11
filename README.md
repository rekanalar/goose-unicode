# goose-unicode

[![ci](https://github.com/rekanalar/goose-unicode/actions/workflows/ci.yml/badge.svg)](https://github.com/rekanalar/goose-unicode/actions/workflows/ci.yml)

Unicode text handling for the [Goose](https://github.com/aardappel/goose)
programming language.

The package validates UTF-8 and names the byte offset of the first
malformed byte. It converts text to the four normalization forms. It
converts case, gives the title case and folds case for caseless compare. It gives the general
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

The tables hold Unicode 18.0.0.

## Install

Add this to the root file of the program that uses it:

```goose
import unicode from "rekanalar/goose-unicode@v0.21.0";
```

## API

| Function | What it does |
|---|---|
| `UNICODE_VERSION` | the version of the Unicode tables, `"18.0.0"`; Python gives it as `unicodedata.unidata_version` |
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
| `nfkc_casefold(out, s)` | writes the NFKC case fold of the text: the match key of a caseless and compatibility-insensitive compare |
| `to_title(out, s)` | writes the text in title case: the first cased letter of each word in title case, the rest in lower case |
| `titlecase_cp(out, cp)` | writes the title case mapping of one code point; a code point with no mapping gives itself |
| `to_upper_locale(out, s, locale)` | writes the upper case of `s` under the rules of the locale |
| `to_lower_locale(out, s, locale)` | writes the lower case of `s` under the rules of the locale, with the final sigma |
| `to_title_locale(out, s, locale)` | writes the title case of `s` under the rules of the locale |
| `locale_of(tag)` | the locale constant of a language tag, such as `tr-TR`; the root locale for any other tag |
| `category(cp)` | the general category of a code point, as a `CAT_` constant |
| `category_group(cp)` | the group of the category, as a `GROUP_` constant: letter, mark, number, punctuation, symbol, separator or other |
| `is_letter_cased(cp)` | true for an upper case, a lower case and a title case letter |
| `category_name(cp)` | the two letter name of the category, such as `Lu` |
| `combining_class(cp)` | the canonical combining class of a code point, from 0 to 240 |
| `script(cp)` | the script of a code point, as a `SCRIPT_` constant |
| `script_name(cp)` | the name of the script, such as `Latin` |
| `script_extensions(out, cp)` | writes the scripts of a code point into the buffer of the caller; a code point with no extension list gives its one script |
| `script_value_name(s)` | the name of a script from its `SCRIPT_` constant |
| `block_name(cp)` | the name of the block, such as `Basic Latin`; `No_Block` when there is none |
| `block_start(cp)`, `block_end(cp)` | the first and the last code point of the block; -1 when there is none |
| `age(cp)` | the major and the minor number of the Unicode release that assigned the code point; 0 and 0 when no release did |
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
| `is_emoji(cp)`, `is_emoji_presentation(cp)`, `is_emoji_modifier(cp)`, `is_emoji_modifier_base(cp)`, `is_emoji_component(cp)`, `is_extended_pictographic(cp)` | the emoji properties of the standard |
| `is_zwj(cp)`, `is_emoji_presentation_selector(cp)`, `is_text_presentation_selector(cp)`, `is_regional_indicator(cp)`, `is_tag_character(cp)` | the code points that build emoji sequences |
| `is_id_start(cp)`, `is_id_continue(cp)`, `is_xid_start(cp)`, `is_xid_continue(cp)` | the identifier properties of the standard |
| `skeleton(out, s)` | writes the skeleton of the text: the key of the confusable table of the standard |
| `confusable(a, b)` | true when the two texts have the same skeleton, so a person reads them the same |
| `has_property(cp, prop)` | true when the code point holds the binary property; `prop` is a `PROP_` constant such as `PROP_WHITE_SPACE` |
| `property_name(prop)`, `property_by_name(name)` | the name of a binary property, such as `White_Space`, and the constant of a name; -1 when there is none |
| `mirrored(cp)` | true when the code point is mirrored |
| `mirror_of(cp)` | the mirror partner of a code point; a code point that is not mirrored gives itself |
| `numeric_value(cp)` | the numeric value as the numerator and the denominator; a denominator of zero means no value |
| `numeric_type(cp)`, `numeric_type_name(cp)` | the numeric type: `NUMTYPE_NONE`, `NUMTYPE_DECIMAL`, `NUMTYPE_DIGIT` or `NUMTYPE_NUMERIC`, and its name |
| `decimal_value(cp)`, `digit_value(cp)` | the decimal digit value and the digit value of a code point; -1 when there is none |
| `decomposition_type(cp)`, `decomposition_type_name(cp)` | the decomposition type, as a `DECOMP_` constant, and its name |
| `decomposition(out, cp)` | writes the one level mapping of a code point into the buffer of the caller |
| `joining_type(cp)`, `joining_type_name(cp)` | the joining type, as a `JOINING_` constant, and its name |
| `joining_group(cp)`, `joining_group_name(cp)` | the joining group as a number, and its name such as `Beh` |
| `bidi_bracket_type(cp)` | the paired bracket type: `BRACKET_NONE`, `BRACKET_OPEN` or `BRACKET_CLOSE` |
| `bidi_paired_bracket(cp)` | the partner of a bracket; a code point that is no bracket gives itself |
| `lookup(name)` | the code point of a name or a formal alias of the Character Database; -1 when there is none |
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
| `line_break_class(cp)` | the `Line_Break` class of a code point, as an `LB_` constant, before rule LB1 resolves it |
| `grapheme_break(cp)` | the `Grapheme_Cluster_Break` of a code point, as its position in the alias file of the standard |
| `grapheme_break_name(cp)` | the short name of that value, such as `LE` or `Virama` |
| `word_break(cp)` | the `Word_Break` of a code point, as its position in the alias file of the standard |
| `word_break_name(cp)` | the short name of that value, such as `LE` or `Virama` |
| `sentence_break(cp)` | the `Sentence_Break` of a code point, as its position in the alias file of the standard |
| `sentence_break_name(cp)` | the short name of that value, such as `LE` or `Virama` |
| `hangul_syllable_type(cp)` | the `Hangul_Syllable_Type` of a code point, as its position in the alias file of the standard |
| `hangul_syllable_type_name(cp)` | the short name of that value, such as `LE` or `Virama` |
| `indic_syllabic_category(cp)` | the `Indic_Syllabic_Category` of a code point, as its position in the alias file of the standard |
| `indic_syllabic_category_name(cp)` | the short name of that value, such as `LE` or `Virama` |
| `indic_positional_category(cp)` | the `Indic_Positional_Category` of a code point, as its position in the alias file of the standard |
| `indic_positional_category_name(cp)` | the short name of that value, such as `LE` or `Virama` |
| `vertical_orientation(cp)` | the `Vertical_Orientation` of a code point, as its position in the alias file of the standard |
| `vertical_orientation_name(cp)` | the short name of that value, such as `LE` or `Virama` |
| `line_breaks(out, s)` | the break opportunities of the text by rules LB1 to LB31; gives the code and the offset of the first bad byte |
| `sentence_offsets(out, s)` | copies the start offset of every sentence into the buffer of the caller |
| `compare(out, a, b)` | the sign of the root collation order of two texts: -1, 0 or 1 |
| `sort_key(out, s)` | the sort key of the text: the primary, the secondary and the tertiary weights |

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
`LOCALE_ROOT` constant names the root locale. The package applies no
language rule under it.

```goose
var out: u8[>..] = [];
unicode::to_upper_full(out, "Straße");   // STRASSE
unicode::to_lower_full(out, "ΟΟΣ ΟΣ");   // οος ος
```

## Title case

The `to_title` call follows the title case algorithm of the Unicode
standard. It splits the text into words with the word rules of the
package. The first cased character of each word takes the title case
mapping. The rest of the word takes the full lower case, with the final
sigma rule. A word with no cased character stays as it is.

```goose
var out: u8[>..] = [];
unicode::to_title(out, "ǆ straße don't");   // ǅ Straße Don't
unicode::titlecase_cp(out, 0xDF);           // Ss
```

The digraph ǆ has a title case form of its own, ǅ. The sharp s gives two
letters when it starts a word. Python `str.title` splits a word at every
character that is no letter, so it gives "Don'T". This package follows the
standard and gives "Don't". The standard, Python and Go all give "1St" for
"1st", and so does this package.

The Go library `golang.org/x/text/cases` approximates the word rules, so
its answers differ for a few texts. Go joins a mid word mark, such as a
full stop or a colon, to a digit. The standard breaks the word there. Go
reads a combining mark after a character that is no letter as part of a word. Go gives the
final sigma after a digit or an uncased letter, and the standard does not.

ICU adds a tailoring of its own. It gives "1st" and splits "ab.cd" into two
words. The package follows the standard in all these cases.

## Case with a locale

The `LOCALE_TR`, `LOCALE_AZ` and `LOCALE_LT` constants name the language
rules of the special casing file of the standard. The `to_upper_locale`,
`to_lower_locale` and `to_title_locale` calls take one of the constants.

A script compares every scalar value with the ICU library, release 79.1, for
the three locales and the three cases. One difference stays. It is the title
case of the lone U+0345. There the package follows the character database,
as `to_title` does. The suite replays 13,311 texts around the rules against ICU.
Node judges the upper and lower case of the code points that it holds.

Turkish and Azerbaijani map the small i to U+0130, the letter with a dot.
They map the capital I to the dotless small i. A dot above after a capital I
joins the letter. So `I` with a dot above gives the small i alone.

```goose
var out: u8[>..] = [];
unicode::to_upper_locale(out, "iı", unicode::LOCALE_TR);      // İI
unicode::to_lower_locale(out, "ISPARTA", unicode::LOCALE_TR); // ısparta
```

Lithuanian adds the dot above to a small i, small j or U+012E when a mark
above follows. The upper case removes the dot above after a soft dotted
letter. U+00CC, U+00CD and U+0128 give the small letter, the dot and the
accent.

```goose
var text: u8[>..] = [];
unicode::utf8_encode(text, 0xCC);   // Ì
unicode::to_lower_locale(out, text[..], unicode::LOCALE_LT);  // i, dot above, grave
```

The `locale_of` call reads the language subtag of a language tag. The subtag
has two or three ASCII letters. It ends at the end of the tag, at a hyphen or
at an underscore. The call gives `LOCALE_TR` for `tr`, `TR`, `tr-TR`, `tr_TR` and `tur`, and the
root locale for any other subtag. With `LOCALE_ROOT` each call gives the
result of the call without a locale. A locale value that is no constant
gives `ERR_BAD_ARG`.

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
print(unicode::lookup("hangul syllable ga"));   // 44032, the code point 0xAC00
let num, den = unicode::numeric_value(0xBD);
print(num, "/", den);                  // 1/2
```

## Numbers, mappings and joining

The numeric type tells a decimal digit from a digit and from a plain
number. A decimal digit has a decimal value and a digit value. A
superscript two has a digit value and no decimal value. A vulgar
fraction has a numeric value from `numeric_value` and neither digit
value.

The `decomposition` call gives the one level mapping of a code point.
The `decomposition_type` call gives its tag. The
mapping of a Hangul syllable is algorithmic. The call gives the jamo, as
Python `unicodedata.decomposition` does, and the type is canonical.
Full normalization stays with `normalize`.

The joining type and group serve the shaping of Arabic and Syriac. The
groups have no constants. The call `joining_group_name` gives the name,
and the call `joining_group` gives a number that follows the order of the
names.

```goose
print(unicode::joining_type_name(0x628));   // Dual_Joining
print(unicode::joining_group_name(0x628));  // Beh
```

The package agrees with the ICU library on every code point. This holds
for the numeric type, the decomposition type and the joining properties.
It holds for the bracket type and partner too. The package agrees with
Python on the decimal value, the digit value and the mapping. Python
holds an older release, so this holds for its code points only.

## Script extensions, blocks and age

Many marks and signs belong to more than one script. The `script`
call gives the one script of the file `Scripts.txt`. The call
`script_extensions` gives the list of the file `ScriptExtensions.txt`.
It gives the one script for a code point that has no list.

The `block_name` call gives the name as `Blocks.txt` spells it, such as
`Latin-1 Supplement`. The ICU library spells the same names with
underscores. The `age` call gives the release that first assigned the
code point.

```goose
var out: i64[>..] = [];
unicode::script_extensions(out, 0x30FC);   // Hiragana and Katakana
let major, minor = unicode::age(0x1F600);  // 6 and 1
```

The package agrees with the ICU library on every code point for the
three properties.

## Emoji and identifiers

The emoji calls give the properties of the emoji data file of the
standard. The `is_emoji_component` call is true for every code point that
holds the property. This includes the zero width joiner, which is no
emoji. The Rust crate `unicode-properties` gives false for the joiner,
against its own documentation. The package follows the standard.

The identifier calls give `ID_Start`, `ID_Continue` and the two `XID`
forms. Each call tests one code point. None checks a whole identifier.

```goose
print(unicode::is_emoji(0x1F600));      // true
print(unicode::is_id_start(0x61));      // true
print(unicode::category_group(0x31));   // 2, GROUP_NUMBER
```

A call with a value outside U+0000 to U+10FFFF gives false. The group of
such a value is `GROUP_OTHER`.

## Binary properties

The `has_property` call answers the yes or no properties of the
standard. The package holds 53 of them. They are the emoji and identifier
properties, `Alphabetic`, `Lowercase`, `Uppercase`, `Cased` and
`Case_Ignorable`. They include the five `Changes_When_` case properties,
`Math`, `Dash`, `Hex_Digit`, `White_Space` and
`Default_Ignorable_Code_Point`. The rest come from the files
`PropList.txt` and `DerivedCoreProperties.txt`, where the references
expose them. `Changes_When_NFKC_Casefolded` is there too.

The `PROP_` constants give the number of each property. The `property_name` call
gives the name.

```goose
print(unicode::has_property(0xA0, unicode::PROP_WHITE_SPACE));   // true
print(unicode::has_property(0x2014, unicode::PROP_DASH));        // true
print(unicode::property_by_name("alphabetic"));                  // PROP_ALPHABETIC
```

A code point outside U+0000 to U+10FFFF and a value that is no property
give false. The `property_by_name` call ignores the case of ASCII letters
and nothing else. It gives -1 for the loose names of ICU, such as
`whitespace`.

## The NFKC case fold

The `nfkc_casefold` call gives the match key of a compare that
ignores case, compatibility and default ignorables at once. Two texts
with the same NFKC case fold differ in none of the three. The
identifier checks and the loose matchers of the standard use this
form.

```goose
var out: u8[>..] = [];
let code, offset = unicode::nfkc_casefold(out, "Straße");
// the fold of the sharp s is "strasse"
```

The order is the order of the standard. The text decomposes first.
Then each code point folds. Then the default ignorables drop out.
One composition runs over the whole text. It runs last, because
folded characters interact.

## Look alike identifiers

The `skeleton` call gives the key of a text under the confusable table
of the standard. The text takes the canonical form first. The default
ignorables drop out. Every code point maps through the table. The
canonical form runs once more over the result. The skeleton keeps the
case, so `a` and `A` differ.

The `confusable` call gives true when two texts have the same
skeleton. A Cyrillic `a` next to a Latin `bc` reads like `abc`. An `m`
reads like `rn`. A caller that accepts identifiers from users can
compare the skeletons, and refuse a name that imitates another.

```goose
print(unicode::confusable("\u0430bc", "abc"));   // true
```

Only the ICU library holds these calls. Python, Node, Go and the Rust
crates hold none. The table comes from the security data of the
standard.

The ICU 79.1 library ships an older revision of the table. The package
uses the current revision, so the two skeletons differ on 228 of the
6,712 rows. Every other row gives the same skeleton. The script
`make_confusable_data.py` counts the difference and writes both
skeletons into the suite.

## Enumerated properties

Seven calls give an enumerated property of a code point. They are
`grapheme_break`, `word_break`, `sentence_break`, `hangul_syllable_type`,
`indic_syllabic_category`, `indic_positional_category` and
`vertical_orientation`. ICU gives them through `u_getIntPropertyValue`, and
the Rust `icu_properties` crate gives them as types. Python, Node and Go
give none of them.

The number is the position of the value in `PropertyValueAliases.txt`,
counted from zero for each property. The `_name` call gives the short name
of the value. A code point outside U+0000 to U+10FFFF gives the default
value of the property.

```goose
print(unicode::sentence_break_name(0x41));            // UP
print(unicode::indic_syllabic_category_name(0x94D));  // Virama
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

## Line breaking

The `line_breaks` call gives the places where a line may end. It uses
the rules LB1 to LB31 of the Unicode line breaking standard (UAX #14). It
writes one entry for each break into the buffer of the caller. An entry
holds the byte offset times two, plus `BREAK_MANDATORY` (1) for a hard
break. The end of a text that is not empty is the last break, and it is
mandatory. An empty text holds no break.

```goose
var brk: i64[>..] = [];
let code, off = unicode::line_breaks(brk, "a b\nc");
// brk is [4, 9, 11]: after "a ", after the line feed, at the end
```

The `line_break_class` call gives the class of one code point as it
stands in `LineBreak.txt`. The call `line_breaks` resolves the classes
AI, SG, XX, SA and CJ by the default rule LB1. It uses the general
category, the East Asian width and the emoji flag where the rules name
them.

The package agrees with every case of `LineBreakTest.txt`. It agrees
with the ICU line iterator on 25,000 random texts. Rust
`unicode-linebreak` holds an older release of the tables. Python and Go
have no such call in the standard library or in `x/text`.

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
`BidiCharacterTest.txt` of Unicode 18.0.0. Python has no such call in the
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

The halfwidth sound marks U+FF9E and U+FF9F count as 1, as in the Rust
crate 0.2.3. They are combining marks in the Unicode data.

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

## Collating

The `compare` call gives the sign of the root collation order of two
texts: -1, 0 or 1. The `sort_key` call gives the sort key of one text
in the buffer of the caller. The key holds the primary weights, then
the secondary weights, then the tertiary weights. A byte value of 1
ends each level, and a byte value of 0 ends the key. The text of an
empty key has no code point. The key of one letter holds six numbers.

The sign of the comparison of two keys equals the sign of `compare`
for the same texts. A caller can sort the keys once and search them
many times.

The order is the root order of the Unicode Collation Algorithm. The
table comes from the root collation of CLDR release 49 at Unicode 18.0.0.
Variable characters keep their primary weight, so a hyphen orders
like a letter. Lower case sorts before upper case through the
tertiary level. The package decomposes each text to the canonical
form first, so two spellings of one text order equal.

The table holds 974 contractions of up to three code points, and the
longest match wins. A contraction also matches across a combining
mark. The mark must order before the next code point of the
sequence. The weights of the skipped mark then follow the weights of
the contraction. The scan across marks stops at a starter and at 32
marks.

A code point with no table row takes the implicit weights of the
algorithm. A Hangul syllable takes the weights of its jamos.

```goose
var out: i64[>..] = [];
let code, offset = unicode::compare(out, "amber", "Apple");
if code == unicode::OK && out[0] == -1 {
    print("amber sorts before Apple\n");
}
```

## Limits

- An identifier is more than the start and continue tests. A caller that
  accepts names from users also normalizes the text to NFC. It checks for
  look alike characters too, as UAX #31 and UAX #39 describe. The package
  gives the tests and no check of a whole name.
- The case mapping holds the language rules of Turkish, Azerbaijani and
  Lithuanian. The Greek upper case, the Dutch IJ title case and the
  Armenian ligature U+0587 stay out. The ICU library, release 79.1, the
  Rust crate `icu_casemap` and Node hold all three.
- The title case of `I` with a dot above differs from the Rust crate
  `icu_casemap` under Turkish. The crate keeps the dot. The package and
  ICU remove it, as the standard says.
- The Lithuanian lower case orders the marks as ICU does. The dot above
  comes before a mark of class 230 and before a mark of class 220.
  Go `x/text` writes a mark of class 220 before the dot. It also adds a
  second dot after U+0130. The package follows ICU.

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
- The `lookup` call matches the whole name. It ignores the case of ASCII
  letters and nothing else. The loose matching of UAX #44 (rule LM2)
  ignores spaces and hyphens too, and the call does not.
  A name of a code point wins over an alias of the same text.

  The call gives one code point, so it holds no named sequence. Python
  `unicodedata.lookup` gives a text of several code points for a sequence.
  Rust `unicode_names2` and ICU give no sequence. The ICU function knows
  the names and the corrections only, and no other alias. A query above
  128 bytes gives -1, and the call has no fault code.
- A block name keeps the spelling of the file of the standard. A code
  point in no block gives `No_Block`, and the block range calls give -1. The
  numbers of the scripts follow the order of the names in the file. A
  later release can add a script and move the numbers. Compare the name.
- The `joining_group` call gives a number and not a named constant. The
  groups follow the order of the names in the file. A later release can
  add a group and move the numbers. Compare the name, not the number.
- The `decomposition` call gives one level, except for a Hangul syllable,
  where it gives the jamo as Python does. The ICU library has no such
  call, so the mapping has Python as its only reference. A value outside
  the range gives the value of an unassigned code point.
- The line breaks follow the default rules and no tailoring. They give no
  dictionary break inside Thai, Lao, Khmer or Burmese. The ICU iterator
  breaks those scripts with a dictionary, so it gives other breaks
  there. The package leaves the width of a line to the caller.
- The bidirectional calls treat a paragraph as one line. A caller that
  breaks a paragraph into lines passes the levels of each line to
  `bidi_order`. The rules L3 and L4 depend on the renderer, and the
  package leaves them out. So do the combining marks and the mirrored
  glyphs. The `mirrored` call gives the mirror flag of a code point.
- The package reads UTF-8, UTF-16 and UTF-32.
- The numbers of the seven enumerated properties follow the alias file, not
  the numbers of ICU. A later release can add a value and move a number.
  Compare the name to stay safe. The package has no constant for each value
  and no call that finds a value by its name. The alias file also holds
  values that the standard no longer uses, such as `E_Base`. They keep
  their positions, and no code point has them.
- The confusable calls give the skeleton and the test of UAX #39. The
  restriction levels, the identifier status checks and the mixed
  script detection of the same report stay out. Only ICU holds the
  calls, and ICU ships an older revision of the table.
- Only the ICU library holds the NFKC case fold as one call
  (`unorm2_getNFKCCasefoldInstance`). Python `str.casefold`, Node,
  Go and the Rust crates hold no such call. The package holds it
  whole, and the suite replays every row of the `NFKC_CF` table of
  the standard. The is-normalized check of ICU on this form stays
  out, because no other reference and no data table support it.
- The binary properties hold the properties that ICU, Node and Go
  expose. The contributory `Other_` properties stay out, and so do the
  deprecated `Hyphen` and `Grapheme_Link`. The properties with more than
  two values have their own calls. Node gives no regex class for five
  properties: `IDS_Unary_Operator`, `Prepended_Concatenation_Mark`,
  `Modifier_Combining_Mark` and the two `ID_Compat_Math` ones. The ICU
  library is the only oracle for those five. The Rust
  `icu_properties` crate is no oracle of this package.
- The collation follows the root locale and no tailoring. The strength,
  the alternate shifted weighting, the numeric order, the case options
  and the script reordering stay out. A caller that needs a locale gets
  the root order here.
- The Han ideographs order by the implicit weights of the algorithm. ICU
  79 and Node order the Han script by the Unihan radical stroke order.
  Go, Rust and the conformance file of the standard follow the implicit
  weights, as this package does.
- The four references carry tables of different Unicode versions. Take
  50,000 random pairs of the whole range. ICU 79.1 differs from Node
  (ICU 78) on 207 pairs, from Rust on 165 and from Go on 560. Most
  differences hold a code point that one table lacks. The script
  `diff_coll.py` prints the differences. The package follows the
  conformance file of CLDR release 49.
- A discontiguous match scans at most 32 marks. A text that holds more
  marks between the parts of a contraction orders the parts apart. ICU
  79 scans the marks without a bound.
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
- The tables hold Unicode 18.0.0. Python `unicodedata` holds Unicode
  16.0.0, so it gives different answers for the code points that Unicode
  17 and 18 added. Node holds Unicode 17.0.0 through ICU 78. Go holds
  Unicode 17.0.0 in the standard library and in
  `golang.org/x/text/unicode/norm`.
- The tests judge every code point against ICU 79.1, which holds Unicode
  18.0.0. Node, Go and Python judge the code points that 18.0.0 did not
  add. Where 18.0.0 changed an older code point, the test names it.
- Unicode 18.0.0 changed three rules. Rule GB9c of the cluster split now
  joins a conjunct linker, any marks and a consonant. A consonant that
  follows a linker joins the cluster, and a mark after the linker no
  longer ends the join. Rule LB12a of the line break no longer allows a
  break between a break-after character and a no-break space. The
  collation gives the Jurchen and Seal ranges their own implicit weights.
- Node holds the earlier GB9c rule. It splits 10 of the 853 held cases of
  the cluster test file as the earlier rule does.
- ICU 79.1 holds no name for the Jurchen and Seal code points. The file
  `DerivedName.txt` names them, and the package gives those names. The
  test checks that ICU gives none. ICU also accepts a name with a space
  at an end, or with a hyphen for a space. The package takes the exact
  name only.
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
- The `lookup` call stops a query above 128 bytes before the search. The
  longest name is 88 bytes. A search takes at most 18 compares of the
  query with a name. A hostile query cannot take more time.
- The line break call decodes the text into one packed number for each
  code point. It reads at most two units ahead. The time is linear in the
  bytes. A hostile text of spaces, combining marks, regional indicators,
  quotes or digits cannot take quadratic time. The text is at most
  `MAX_INPUT` bytes, and the arrays hold two numbers for each code point.
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
- The collation walk reads each text once and holds the weights of one
  unit at a time. The discontiguous scan takes at most 32 marks per
  start. A hostile text of Tibetan marks or of long mark runs cannot
  take quadratic time. A key above `MAX_OUTPUT` gives `ERR_TOO_LONG`
  and writes nothing.

- The fold of a hostile text is one decode, one decomposition, one
  fold pass and one composition. The composition sorts long runs of
  marks with a counting sort. A hostile run of marks cannot take
  quadratic time. A result above `MAX_OUTPUT` gives `ERR_TOO_LONG`
  and writes nothing.
- The skeleton walk takes the longest match at each position, so the
  time stays linear in the bytes. A hostile text of the letter m grows
  the result, and the bound gives `ERR_TOO_LONG` and writes nothing.
  A bad byte gives `ERR_BAD_UTF8` and its offset.
- The `property_by_name` call stops a query above 28 bytes before any
  compare. The longest name holds 28 bytes. A search makes at most 53
  compares of the length of the query. A hostile query cannot take more
  time.

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
goose run examples/title.goose
goose run examples/bidi.goose
goose run examples/flags.goose
goose run examples/linebreak.goose
goose run examples/collate.goose
goose run examples/properties.goose
goose run examples/casefold.goose
goose run examples/confusable.goose
goose run examples/lookup.goose
goose run examples/enumprops.goose
goose run examples/chars.goose
goose run examples/scripts.goose
```

The scripts under `test/` build the tables of the package. They read the
files of the Unicode Character Database 18.0.0 and write numbers only.
Each script checks its table against a second source and fails on a
difference. The sources are the Go standard library and the packages of
`golang.org/x/text`. They are also the ICU library 79.1, Node with ICU 78,
Python and the Rust `unicode-width` crate 0.2.3.

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
`https://www.unicode.org/Public/18.0.0/ucd/`. The word, sentence and line break
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
python3 make_title_data.py
python3 make_flags_data.py
python3 make_line_data.py
python3 make_name_data.py
python3 make_char_data.py
python3 make_script_data.py
python3 make_enum_data.py
python3 diff_line.py
python3 make_coll_data.py
python3 diff_coll.py
python3 diff_props.py
python3 make_casefold_data.py
python3 make_confusable_data.py
```

The collation script reads the root collation table and the conformance
texts of the CLDR repository. It writes the table of the package and
the pairs of the suite. It asks the ICU library for the sign of each
random pair. The script `diff_coll.py` compares random pairs with the
ICU library, the Go package, Node and the Rust `icu_collator` crate.

The title script checks its table against the Go library and the Rust
`unicode-case-mapping` crate. The crate holds an older release of the
standard, so the script warns about the newest code points. The script
`diff_title.py` compares random texts with the Go library. The flags script
checks every binary property against the ICU library and Node over every
code point. The script `diff_props.py` compares the properties that Go
holds.

## License

MIT
