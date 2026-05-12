; Inherit standard TOML highlighting by not overriding it.
; The TOML grammar highlights table headers, keys, strings, numbers, and booleans.
; We add semantic distinction for known Move.toml table names.

; Known Move.toml section headers get namespace highlighting
((table (bare_key) @namespace)
 (#match? @namespace "^(package|dependencies|dev-dependencies|addresses|dev-addresses)$"))

; Known dependency keys
((pair (bare_key) @property)
 (#match? @property "^(git|rev|subdir|local|addr)$"))

; Named address values (hex addresses) get constant.builtin
((string) @constant.builtin
 (#match? @constant.builtin "^\"0x[0-9a-fA-F]+\"$"))
