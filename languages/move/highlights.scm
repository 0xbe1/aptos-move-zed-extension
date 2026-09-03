; Comments
(line_comment) @comment
(block_comment) @comment

; ─── Literals ───────────────────────────────────────────────────────────────
(bool_literal) @boolean
(num_literal) @number
(byte_string_literal) @string
(hex_string_literal) @string
(numerical_address) @constant.builtin

; ─── Keywords ───────────────────────────────────────────────────────────────
; Declaration keywords
[
  "module"
  "script"
  "address"
  "fun"
  "struct"
  "enum"
  "const"
  "use"
  "friend"
  "spec"
  "schema"
] @keyword

; Modifier keywords (anonymous tokens)
[
  "public"
  "native"
  "package"
  "phantom"
  "has"
] @keyword.modifier

; Modifiers wrapped in named nodes
(entry_modifier) @keyword.modifier
(inline_modifier) @keyword.modifier

; Storage abilities (the words copy/drop/store/key when used as abilities)
[
  "key"
  "store"
  "drop"
] @type.builtin

; Variable bindings
[
  "let"
] @keyword

; Control flow
[
  "if"
  "else"
  "match"
  "while"
  "loop"
  "for"
  "return"
  "break"
  "continue"
  "abort"
  "in"
] @keyword.control

; Move-specific expression keywords
[
  "move"
  "copy"
  "as"
  "is"
  "acquires"
  "where"
  "to"
] @keyword

; Spec keywords
[
  "invariant"
  "ensures"
  "requires"
  "aborts_if"
  "aborts_with"
  "modifies"
  "emits"
  "decreases"
  "succeeds_if"
  "assume"
  "assert"
  "axiom"
  "include"
  "apply"
  "pragma"
  "global"
  "local"
  "post"
  "forall"
  "exists"
  "choose"
  "min"
  "with"
  "except"
  "internal"
  "update"
] @keyword

; Boolean literal keywords
[
  "true"
  "false"
] @boolean

; ─── Operators ──────────────────────────────────────────────────────────────
[
  "+"
  "-"
  "*"
  "/"
  "%"
  "=="
  "!="
  "<"
  ">"
  "<="
  ">="
  "&&"
  "||"
  "!"
  "&"
  "|"
  "^"
  "<<"
  ">>"
  "="
  "=>"
  ".."
  "::"
] @operator

; ─── Punctuation ────────────────────────────────────────────────────────────
[
  "("
  ")"
  "["
  "]"
  "{"
  "}"
] @punctuation.bracket

[
  ","
  ";"
  ":"
  "."
] @punctuation.delimiter

; ─── Module / namespace declarations ────────────────────────────────────────
(module_declaration
  name: (identifier) @namespace)

; Address blocks
(address_block) @namespace

; ─── Use declarations ───────────────────────────────────────────────────────
(use_module
  (module_identity) @namespace)
(use_member
  member: (identifier) @variable)
(use_alias
  alias: (identifier) @variable)

; Friend declarations target a module
(friend_declaration
  (name_access_chain) @namespace)

; ─── Function declarations ──────────────────────────────────────────────────
(function_declaration
  name: (identifier) @function)

; ─── Function calls ─────────────────────────────────────────────────────────
; Highlight the whole call target chain; specific patterns above (e.g. namespace
; portions inside name_access_chain) can refine this further.
(call_expression
  function: (name_access_chain
    (identifier) @function.call))

(macro_call_expression
  macro: (macro_identifier) @function.macro)

; ─── Built-in functions ─────────────────────────────────────────────────────
((identifier) @function.builtin
  (#match? @function.builtin "^(assert|move_to|move_from|borrow_global|borrow_global_mut|exists|freeze)$"))

; ─── Struct / Enum declarations ─────────────────────────────────────────────
(struct_declaration
  name: (identifier) @type)

(enum_declaration
  name: (identifier) @type)

; Enum variants — name highlighted as constructor
(enum_variant
  name: (identifier) @constructor)

; ─── Type references ────────────────────────────────────────────────────────
(apply_type
  (name_access_chain
    (identifier) @type))

(primitive_type) @type.builtin

; Type parameter declarations: <T, U: copy + drop>
(type_parameter
  name: (identifier) @type.parameter)

; ─── Constants ──────────────────────────────────────────────────────────────
(constant_declaration
  name: (identifier) @constant)

; ─── Abilities ──────────────────────────────────────────────────────────────
(ability) @type.builtin

; ─── Attributes (#[test], #[expected_failure], etc.) ────────────────────────
(attributes) @attribute
(attribute) @attribute

; ─── Struct fields ──────────────────────────────────────────────────────────
(field_declaration
  name: (identifier) @property)

(field_initializer
  field: (identifier) @property)

(field_pattern
  field: (identifier) @property)

; Receiver-style method call: x.method(...) — the callee is a function, not a
; field. Uses the same @function.call family as free-function calls above so
; call sites style uniformly across themes. Must precede the plain
; field-access rule below so calls are painted as functions, not properties.
(dot_expression
  field: (identifier) @function.call
  arguments: (arg_list))

; Field access: x.field
(dot_expression
  field: (identifier) @property)

; ─── Function parameters / lambdas ──────────────────────────────────────────
(function_parameter
  name: (identifier) @variable.parameter)

(lambda_parameter
  (bind_var
    (identifier) @variable.parameter))

; ─── Variable bindings ──────────────────────────────────────────────────────
(bind_var
  (identifier) @variable)

; Self parameter in receiver functions
((identifier) @variable.special
  (#eq? @variable.special "self"))

; ─── Catch-all: any other identifier is a variable reference ────────────────
(identifier) @variable
