; Run indicators (▶) for unit tests and Move Prover targets.
;
; The captures below feed Zed's runnable indicators:
;   - `@run` marks where the ▶ button appears
;   - any other non-underscore capture becomes a `ZED_CUSTOM_<NAME>` variable
;     for the task bound to the tag
;
; Bind these tags to tasks in your `.zed/tasks.json` (see templates/tasks.json
; in this repository):
;   - `move-test`  → e.g. `aptos move test --filter $ZED_CUSTOM_TEST`
;   - `move-prove` → e.g. `aptos move prove --filter $ZED_CUSTOM_MODULE`

; ▶ on `#[test]` functions (exact match: `#[test_only]` and friends excluded)
(
  (function_declaration
    (attributes
      (attribute
        (name_access_chain
          (identifier) @_attr_name
          (#eq? @_attr_name "test"))))
    name: (identifier) @run @test)
  (#set! tag move-test)
)

; ▶ on module declarations, for proving a single module
(
  (module_declaration
    name: (identifier) @run @module)
  (#set! tag move-prove)
)

(
  (module_declaration
    name: (module_identity
      module: (identifier) @run @module))
  (#set! tag move-prove)
)
