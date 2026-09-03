; Move.toml highlighting.
;
; IMPORTANT: Zed does NOT inherit queries across languages. The `Move.toml`
; language is distinct from the built-in `TOML` language, so this file must
; contain the complete TOML base highlighting (mirrored from the official
; zed-extensions/toml queries) plus the Move-specific rules at the end.
; Later patterns win over earlier ones for the same span, so the
; Move-specific captures below override the generic base captures.

; --- TOML base --------------------------------------------------------------

; Properties
;-----------
(bare_key) @property

(quoted_key) @property

; Literals
;---------
(boolean) @constant

(comment) @comment

(integer) @number

(float) @number

(string) @string

(escape_sequence) @string.escape

(offset_date_time) @string.special

(local_date_time) @string.special

(local_date) @string.special

(local_time) @string.special

; Punctuation
;------------
[
  "."
  ","
] @punctuation.delimiter

"=" @operator

[
  "["
  "]"
  "[["
  "]]"
  "{"
  "}"
] @punctuation.bracket

; --- Move-specific overrides ------------------------------------------------

; Known Move.toml section headers get namespace highlighting
((table
  "["
  (bare_key) @namespace)
 (#match? @namespace "^(package|dependencies|dev-dependencies|addresses|dev-addresses)$"))

((table_array_element
  "[["
  (bare_key) @namespace)
 (#match? @namespace "^(dependencies|dev-dependencies)$"))

; Known dependency keys inside inline tables, e.g.
; Foo = { git = "...", rev = "...", subdir = "...", local = "...", addr = "..." }
((inline_table
  (pair
    (bare_key) @variable.other.member))
 (#match? @variable.other.member "^(git|rev|subdir|local|addr)$"))

; Named address values (hex addresses) get constant.builtin, e.g.
; test_addr = "0x42"
((string) @constant.builtin
 (#match? @constant.builtin "^\"0x[0-9a-fA-F]+\"$"))
