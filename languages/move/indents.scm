; Generic blocks
(block) @indent

; Function bodies
(function_declaration
  body: (block) @indent)

; Module body
(module_declaration) @indent

; If/else expressions
(if_expression) @indent

; Loop expressions
(while_expression) @indent
(loop_expression) @indent
(for_expression) @indent
