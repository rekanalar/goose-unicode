// The oracle of the locale aware case mapping. Arguments: a language
// tag and one of upper, lower, title. Each input line holds the code
// points of one text in hex, separated by spaces. The output holds the
// converted text in the same form, from the icu_casemap crate. The
// title mode takes the text as one segment: the first cased character
// gets the title case and the rest gets the lower case.
use icu_casemap::options::TitlecaseOptions;
use icu_casemap::CaseMapper;
use icu_locale::LanguageIdentifier;
use std::io::{BufRead, Write};

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let langid: LanguageIdentifier = args[1].parse().unwrap_or(LanguageIdentifier::UNKNOWN);
    let kind = args[2].as_str();
    let cm = CaseMapper::new();
    let out = std::io::stdout();
    let mut w = std::io::BufWriter::new(out.lock());
    for line in std::io::stdin().lock().lines() {
        let line = line.unwrap();
        let s: String = line
            .split_whitespace()
            .map(|h| char::from_u32(u32::from_str_radix(h, 16).unwrap()).unwrap())
            .collect();
        let r = match kind {
            "upper" => cm.uppercase_to_string(&s, &langid).into_owned(),
            "lower" => cm.lowercase_to_string(&s, &langid).into_owned(),
            _ => cm
                .titlecase_segment_with_only_case_data_to_string(&s, &langid, TitlecaseOptions::default())
                .into_owned(),
        };
        let hex: Vec<String> = r.chars().map(|c| format!("{:04X}", c as u32)).collect();
        let _ = writeln!(w, "{}", hex.join(" "));
    }
}
