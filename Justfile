default: build

build:
	cargo build --target wasm32-wasip2 --release

check:
	cargo check --target wasm32-wasip2

fmt:
	cargo fmt

fmt-check:
	cargo fmt --check

clippy:
	cargo clippy --target wasm32-wasip2 -- -D warnings

clean:
	cargo clean

ci:
	cargo fmt --check
	cargo clippy --locked --target wasm32-wasip2 -- -D warnings
	cargo build --locked --target wasm32-wasip2 --release
