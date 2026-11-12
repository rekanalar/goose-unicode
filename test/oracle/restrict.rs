// The restriction levels of the Rust unicode-security crate. Each input
// line holds the code points of one text in hex. The output holds the
// level of the text, the mixed script test and the scripts of the
// resolved set.
//
// The level of the first column runs from 0 for ASCII only to 5 for
// unrestricted. The second column holds 1 for a mixed script text and 0
// for a single script text. The third column holds the short names of
// the scripts of the resolved set, joined by a comma.
//
// The crate holds no whole script test. Its augmented script set holds
// no Hntl. Its step 7 of the level asks for a set of exactly one
// script. The package follows the standard, so the two differ on some
// texts. The crate uses the profile of the identifier profile, so a
// code point outside the profile gives the level 5.
use std::io::{self, BufRead};
use unicode_security::{MixedScript, RestrictionLevel, RestrictionLevelDetection};

fn main() {
    let stdin = io::stdin();
    for line in stdin.lock().lines() {
        let line = line.unwrap();
        let text: String = line
            .split_whitespace()
            .map(|h| char::from_u32(u32::from_str_radix(h, 16).unwrap()).unwrap())
            .collect();
        let level = match text.detect_restriction_level() {
            RestrictionLevel::ASCIIOnly => 0,
            RestrictionLevel::SingleScript => 1,
            RestrictionLevel::HighlyRestrictive => 2,
            RestrictionLevel::ModeratelyRestrictive => 3,
            RestrictionLevel::MinimallyRestrictive => 4,
            RestrictionLevel::Unrestricted => 5,
        };
        let set = text.resolve_script_set();
        let mut names: Vec<String> = Vec::new();
        if set.hanb {
            names.push("Hanb".to_string());
        }
        if set.jpan {
            names.push("Jpan".to_string());
        }
        if set.kore {
            names.push("Kore".to_string());
        }
        for script in set.base.iter() {
            names.push(script.short_name().to_string());
        }
        names.sort();
        names.dedup();
        let mixed = if text.is_single_script() { 0 } else { 1 };
        println!("{} {} {}", level, mixed, names.join(","));
    }
}
