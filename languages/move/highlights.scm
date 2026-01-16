; Syntax highlighting for Aptos Move
; Minimal version using only validated node types

; Comments
(line_comment) @comment
(block_comment) @comment

; Literals
(bool_literal) @boolean
(number) @number
(byte_string) @string
(numerical_addr) @constant.builtin

; Module declarations
(module
  name: (identifier) @namespace)

; Function declarations
(function_decl
  name: (identifier) @function)

; Struct declarations
(struct_decl
  name: (identifier) @type)

; Enum declarations
(enum_decl
  name: (identifier) @type)

; Constant declarations
(constant_decl
  name: (identifier) @constant)

; Type references
(primitive_type) @type.builtin

; Abilities
(ability) @attribute

; Attributes
(attribute) @attribute

; Field annotations
(field_annot
  field: (identifier) @property)

; Parameters
(parameter
  variable: (identifier) @variable.parameter)

; Field access
(access_field
  field: (identifier) @property)

; Control flow expressions
(break_expr) @keyword.control
(continue_expr) @keyword.control
(return_expr) @keyword.control
(abort_expr) @keyword.control

; Operators
(binary_operator) @operator

; Built-in functions
((identifier) @function.builtin
  (#match? @function.builtin "^(assert|move_to|move_from|borrow_global|borrow_global_mut|exists|freeze|vector)$"))

; All other identifiers
(identifier) @variable
