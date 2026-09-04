/// Move 2 features — exercises enum highlighting, receiver-style method
/// calls, and enum variant constructors.
///
/// Note: Move has no receiver-style *declaration* syntax — the receiver is
/// just the first parameter (conventionally named `self`). Receiver style
/// exists at call sites only: `x.area()` desugars to `area(&x)`.
module test_addr::move2 {
    use std::string::String;

    // Enum declaration — should highlight name as @type, variants as @constructor
    enum Shape has copy, drop {
        Circle { radius: u64 },
        Rectangle { width: u64, height: u64 },
        Triangle { base: u64, height: u64 },
    }

    enum Color has copy, drop {
        Red,
        Green,
        Blue,
        Custom { r: u8, g: u8, b: u8 },
    }

    enum Result<T> has copy, drop {
        Ok(T),
        Err(String),
    }

    // Receiver-callable functions: the first parameter is the receiver,
    // enabling `shape.area()` at call sites (see tests below).
    public fun area(self: &Shape): u64 {
        match (self) {
            Shape::Circle { radius } => {
                // pi * r^2, approximated as 3 * r^2 for integer math
                3 * radius * radius
            },
            Shape::Rectangle { width, height } => width * height,
            Shape::Triangle { base, height } => base * height / 2,
        }
    }

    public fun perimeter(self: &Shape): u64 {
        match (self) {
            Shape::Circle { radius } => 6 * radius,
            Shape::Rectangle { width, height } => 2 * (width + height),
            Shape::Triangle { base, height: _ } => base * 3,
        }
    }

    public fun to_hex(self: &Color): u32 {
        match (self) {
            Color::Red    => 0xFF0000,
            Color::Green  => 0x00FF00,
            Color::Blue   => 0x0000FF,
            Color::Custom { r, g, b } => {
                (*r as u32) << 16 | (*g as u32) << 8 | (*b as u32)
            },
        }
    }

    public fun unwrap_or<T: copy>(result: &Result<T>, default: T): T {
        match (result) {
            Result::Ok(v) => *v,
            Result::Err(_) => default,
        }
    }

    #[test]
    fun test_circle_area() {
        let c = Shape::Circle { radius: 5 };
        assert!(c.area() == 75, 0);
    }

    #[test]
    fun test_rectangle_perimeter() {
        let r = Shape::Rectangle { width: 4, height: 3 };
        assert!(r.perimeter() == 14, 1);
    }

    #[test]
    fun test_color_hex() {
        assert!(Color::Red.to_hex() == 0xFF0000, 2);
        let custom = Color::Custom { r: 0x12, g: 0x34, b: 0x56 };
        assert!(custom.to_hex() == 0x123456, 3);
    }

    #[test]
    fun test_result_unwrap() {
        let ok: Result<u64> = Result::Ok(42);
        assert!(unwrap_or(&ok, 0) == 42, 4);
        let err: Result<u64> = Result::Err(std::string::utf8(b"oops"));
        assert!(unwrap_or(&err, 99) == 99, 5);
    }
}
