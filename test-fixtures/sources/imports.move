/// Imports test module — exercises auto-import completions and organize imports.
///
/// To test B1 (auto-import): delete one of the `use` lines below, then
/// start typing the unimported symbol — the completion should offer to insert it.
///
/// To test B2 (organize imports): shuffle the `use` lines out of order,
/// then trigger Code Actions (⌘.) → "Organize Imports".
module test_addr::imports {
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::event;
    use aptos_std::table::{Self, Table};
    use std::signer;
    use std::string::{Self, String};
    use std::vector;

    struct Store has key {
        items: Table<String, u64>,
        event_handle: event::EventHandle<ItemAdded>,
    }

    struct ItemAdded has drop, store {
        key: String,
        value: u64,
    }

    public fun new_store(owner: &signer): Store {
        let addr = signer::address_of(owner);
        account::create_account_if_does_not_exist(addr);
        Store {
            items: table::new(),
            event_handle: account::new_event_handle<ItemAdded>(owner),
        }
    }

    public fun insert(store: &mut Store, key: String, value: u64) {
        table::upsert(&mut store.items, key, value);
    }

    public fun get(store: &Store, key: &String): u64 {
        *table::borrow(&store.items, *key)
    }

    public fun keys_count(_store: &Store): u64 {
        0 // placeholder
    }

    // Intentionally unused import below — test B2 remove-unused-imports:
    // the `coin` import above is unused and should be flagged.
    fun _use_coin_to_suppress_warning() {
        let _ = coin::zero<aptos_framework::aptos_coin::AptosCoin>();
    }

    fun _use_vector() {
        let _v: vector<u8> = vector::empty();
    }

    #[test(owner = @test_addr)]
    fun test_store_insert_and_get(owner: &signer) {
        let store = new_store(owner);
        let key = string::utf8(b"answer");
        insert(&mut store, key, 42);
        assert!(get(&store, &string::utf8(b"answer")) == 42, 0);
        let Store { items, event_handle } = store;
        table::destroy_empty(items);
        event::destroy_handle(event_handle);
    }
}
