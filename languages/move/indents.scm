; Indentation rules for Move
; Using simple block-based indentation

; Generic blocks
(block) @indent

; Function bodies
(function_decl
  body: (block) @indent)

; Module body
(module) @indent

; If/else expressions
(if_expr) @indent

; Loop expressions
(while_expr) @indent
(loop_expr) @indent
(for_loop_expr) @indent
