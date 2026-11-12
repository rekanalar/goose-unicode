// unicode - Unicode text handling for Goose.
//
// The package validates UTF-8 and reports the offset of the first bad
// byte. It converts text to the four normalization forms. It converts
// case and folds case for caseless compare. It gives the general category
// and the combining class of a code point. It splits text into grapheme
// clusters. The tables hold Unicode 18.0.0.
//
// Every call checks the length of its input before any other work. Every
// call that writes text checks the length of its result. A fault holds a
// code and an offset. It never holds bytes of the input.
namespace unicode;

import std;
import unicode_data;
import normalize_data;
import grapheme_data;
import props_data;
import flags_data;
import case_full_data;
import title_data;
import table;
import utf8;
import lang;
import utf16;
import utf32;
import bom;
import norm;
import casing;
import property;
import grapheme;
import props;
import name_data;
import names;
import char_data;
import chars;
import script_data;
import scripts_more;
import flags;
import case_locale;
import greek_upper_data;
import greek_upper;
import case_full;
import title;
import segment_data;
import word;
import sentence;
import sent_abbr_data;
import sent_abbr;
import width_data;
import width;
import bidi_data;
import linebreak_data;
import bidi;
import linebreak;
import coll_data;
import collate;
import confusable_data;
import confusable;
import enum_data;
import enumprop;
import dict_data_thai;
import dict_data_lao;
import dict_data_burmese;
import dict_data_khmer;
import dict_data_cj;
import dict_match;
import dict_engine;
import dict_cj;

// The Unicode version of the tables.
const UNICODE_VERSION: u8[] = "18.0.0";

// ---- fault codes ----------------------------------------------------
const OK: i64 = 0;
const ERR_BAD_UTF8: i64 = 1;       // the bytes are not well formed UTF-8
const ERR_BAD_CODEPOINT: i64 = 2;  // a surrogate, a negative value or a value above 0x10FFFF
const ERR_BAD_FORM: i64 = 3;       // the normalization form is unknown
const ERR_TOO_LONG: i64 = 4;       // the input or the result is above its bound
const ERR_BAD_ARG: i64 = 5;        // an argument is out of range
const ERR_BAD_UTF16: i64 = 6;      // the bytes are not well formed UTF-16
const ERR_BAD_UTF32: i64 = 7;      // the bytes are not well formed UTF-32

// ---- bounds ---------------------------------------------------------
const MAX_INPUT: i64 = 1048576;    // bytes of input
const MAX_OUTPUT: i64 = 4194304;   // bytes of result

// ---- normalization forms --------------------------------------------
const FORM_NFC: i64 = 0;
const FORM_NFD: i64 = 1;
const FORM_NFKC: i64 = 2;
const FORM_NFKD: i64 = 3;

// ---- general categories ---------------------------------------------
const CAT_CN: i64 = 0;   // unassigned
const CAT_LU: i64 = 1;   // uppercase letter
const CAT_LL: i64 = 2;   // lowercase letter
const CAT_LT: i64 = 3;   // titlecase letter
const CAT_LM: i64 = 4;   // modifier letter
const CAT_LO: i64 = 5;   // other letter
const CAT_MN: i64 = 6;   // nonspacing mark
const CAT_MC: i64 = 7;   // spacing combining mark
const CAT_ME: i64 = 8;   // enclosing mark
const CAT_ND: i64 = 9;   // decimal number
const CAT_NL: i64 = 10;  // letter number
const CAT_NO: i64 = 11;  // other number
const CAT_PC: i64 = 12;  // connector punctuation
const CAT_PD: i64 = 13;  // dash punctuation
const CAT_PS: i64 = 14;  // open punctuation
const CAT_PE: i64 = 15;  // close punctuation
const CAT_PI: i64 = 16;  // initial punctuation
const CAT_PF: i64 = 17;  // final punctuation
const CAT_PO: i64 = 18;  // other punctuation
const CAT_SM: i64 = 19;  // math symbol
const CAT_SC: i64 = 20;  // currency symbol
const CAT_SK: i64 = 21;  // modifier symbol
const CAT_SO: i64 = 22;  // other symbol
const CAT_ZS: i64 = 23;  // space separator
const CAT_ZL: i64 = 24;  // line separator
const CAT_ZP: i64 = 25;  // paragraph separator
const CAT_CC: i64 = 26;  // control
const CAT_CF: i64 = 27;  // format
const CAT_CS: i64 = 28;  // surrogate
const CAT_CO: i64 = 29;  // private use

// ---- grapheme break classes ------------------------------------------
const GB_OTHER: i64 = 0;
const GB_CR: i64 = 1;
const GB_LF: i64 = 2;
const GB_CONTROL: i64 = 3;
const GB_EXTEND: i64 = 4;
const GB_ZWJ: i64 = 5;
const GB_REGIONAL_INDICATOR: i64 = 6;
const GB_PREPEND: i64 = 7;
const GB_SPACINGMARK: i64 = 8;
const GB_L: i64 = 9;
const GB_V: i64 = 10;
const GB_T: i64 = 11;
const GB_LV: i64 = 12;
const GB_LVT: i64 = 13;

// ---- word break classes ------------------------------------------------
const WB_CR: i64 = 1;
const WB_LF: i64 = 2;
const WB_NEWLINE: i64 = 3;
const WB_EXTEND: i64 = 4;
const WB_ZWJ: i64 = 5;
const WB_REGIONAL_INDICATOR: i64 = 6;
const WB_FORMAT: i64 = 7;
const WB_KATAKANA: i64 = 8;
const WB_HEBREW_LETTER: i64 = 9;
const WB_ALETTER: i64 = 10;
const WB_SINGLE_QUOTE: i64 = 11;
const WB_DOUBLE_QUOTE: i64 = 12;
const WB_MIDNUMLET: i64 = 13;
const WB_MIDLETTER: i64 = 14;
const WB_MIDNUM: i64 = 15;
const WB_NUMERIC: i64 = 16;
const WB_EXTENDNUMLET: i64 = 17;
const WB_WSEGSPACE: i64 = 18;
const WB_CJ: i64 = 19;      // Han or Hiragana: a word of the CJK dictionary

// ---- sentence break classes ---------------------------------------------
const SB_CR: i64 = 1;
const SB_LF: i64 = 2;
const SB_EXTEND: i64 = 3;
const SB_SEP: i64 = 4;
const SB_FORMAT: i64 = 5;
const SB_SP: i64 = 6;
const SB_LOWER: i64 = 7;
const SB_UPPER: i64 = 8;
const SB_OLETTER: i64 = 9;
const SB_NUMERIC: i64 = 10;
const SB_ATERM: i64 = 11;
const SB_SCONTINUE: i64 = 12;
const SB_STERM: i64 = 13;
const SB_CLOSE: i64 = 14;
const SB_BAD: i64 = 15;    // a malformed byte; no table holds it

// ---- script values ---------------------------------------------------
// The scripts of the standard follow Common and Inherited. The generator
// assigns the other scripts in the order of the file of the standard.
const SCRIPT_UNKNOWN: i64 = 0;    // the code point is outside the range of the standard
const SCRIPT_COMMON: i64 = 1;     // the code point belongs to no script
const SCRIPT_INHERITED: i64 = 2;  // the code point takes the script around it

// ---- Groups of the general category -----------------------------------
const GROUP_LETTER: i64 = 0;       // Lu, Ll, Lt, Lm, Lo
const GROUP_MARK: i64 = 1;         // Mn, Mc, Me
const GROUP_NUMBER: i64 = 2;       // Nd, Nl, No
const GROUP_PUNCTUATION: i64 = 3;  // Pc, Pd, Ps, Pe, Pi, Pf, Po
const GROUP_SYMBOL: i64 = 4;       // Sm, Sc, Sk, So
const GROUP_SEPARATOR: i64 = 5;    // Zs, Zl, Zp
const GROUP_OTHER: i64 = 6;        // Cc, Cf, Cs, Co, Cn

// ---- East Asian widths ------------------------------------------------
const WIDTH_NEUTRAL: i64 = 0;    // narrow in every text
const WIDTH_NARROW: i64 = 1;     // narrow in an East Asian text
const WIDTH_AMBIGUOUS: i64 = 2;  // wide or narrow in an East Asian text
const WIDTH_WIDE: i64 = 3;       // wide in every text
const WIDTH_FULLWIDTH: i64 = 4;  // wide and takes a full cell
const WIDTH_HALFWIDTH: i64 = 5;  // takes half a cell

// ---- bidirectional classes --------------------------------------------
// The classes follow the order of the file of the standard.
const BIDI_L: i64 = 0;     // left to right
const BIDI_R: i64 = 1;     // right to left
const BIDI_AL: i64 = 2;    // arabic letter
const BIDI_EN: i64 = 3;    // european number
const BIDI_ES: i64 = 4;    // european number separator
const BIDI_ET: i64 = 5;    // european number terminator
const BIDI_AN: i64 = 6;    // arabic number
const BIDI_CS: i64 = 7;    // common number separator
const BIDI_NSM: i64 = 8;   // non spacing mark
const BIDI_BN: i64 = 9;    // boundary neutral
const BIDI_B: i64 = 10;    // paragraph separator
const BIDI_S: i64 = 11;    // segment separator
const BIDI_WS: i64 = 12;   // white space
const BIDI_ON: i64 = 13;   // other neutral
const BIDI_LRE: i64 = 14;  // left to right embedding
const BIDI_LRO: i64 = 15;  // left to right override
const BIDI_RLE: i64 = 16;  // right to left embedding
const BIDI_RLO: i64 = 17;  // right to left override
const BIDI_PDF: i64 = 18;  // pop directional format
const BIDI_LRI: i64 = 19;  // left to right isolate
const BIDI_RLI: i64 = 20;  // right to left isolate
const BIDI_FSI: i64 = 21;  // first strong isolate
const BIDI_PDI: i64 = 22;  // pop directional isolate
