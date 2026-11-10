// Prints the Line_Break class of every code point from the Rust
// unicode-linebreak crate: the code point in hex and the name of the
// class variant.
use unicode_linebreak::break_property;

fn main() {
    for cp in 0u32..=0x10FFFF {
        if char::from_u32(cp).is_some() {
            println!("{:04X} {:?}", cp, break_property(cp));
        }
    }
}
