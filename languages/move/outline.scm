; Code outline / breadcrumbs. Also makes `$ZED_SYMBOL` resolve to the
; enclosing function name for tasks (e.g. `aptos move test --filter $ZED_SYMBOL`).

; Modules
(module_declaration
  name: (identifier) @name) @item

(module_declaration
  name: (module_identity
    module: (identifier) @name)) @item

; Functions
(function_declaration
  name: (identifier) @name) @item

; Structs
(struct_declaration
  name: (identifier) @name) @item

; Enums
(enum_declaration
  name: (identifier) @name) @item

; Constants
(constant_declaration
  name: (identifier) @name) @item
