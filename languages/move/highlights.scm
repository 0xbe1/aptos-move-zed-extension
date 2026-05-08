; Comments
(line_comment) @comment
(block_comment) @comment

; Literals
(bool_literal) @boolean
(num_literal) @number
(byte_string_literal) @string
(hex_string_literal) @string
(numerical_address) @constant.builtin

; Module declarations
(module_declaration
  name: (identifier) @namespace)

; Function declarations
(function_declaration
  name: (identifier) @function)

; Struct declarations
(struct_declaration
  name: (identifier) @type)

; Enum declarations
(enum_declaration
  name: (identifier) @type)

; Enum variants (Move 2)
(enum_variant
  name: (identifier) @constructor)

; Constant declarations
(constant_declaration
  name: (identifier) @constant)

; Type references
(primitive_type) @type.builtin

; Abilities
(ability) @attribute

; Attributes
(attribute) @attribute

; Struct field declarations
(field_declaration
  name: (identifier) @property)

; Parameters
(function_parameter
  name: (identifier) @variable.parameter)

; Field access via dot
(dot_expression
  field: (identifier) @property)

; Control flow
(break_expression) @keyword.control
(continue_expression) @keyword.control
(return_expression) @keyword.control
(abort_expression) @keyword.control

; Built-in functions
((identifier) @function.builtin
  (#match? @function.builtin "^(assert|move_to|move_from|borrow_global|borrow_global_mut|exists|freeze|vector)$"))

; All other identifiers
(identifier) @variable
