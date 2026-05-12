/// Basic module — exercises highlighting, hover, and completions.
module test_addr::basic {
    use std::string::{Self, String};
    use std::vector;
    use aptos_framework::account;

    struct Counter has key, store {
        value: u64,
    }

    struct Registry has key {
        counters: vector<Counter>,
    }

    public fun new_counter(): Counter {
        Counter { value: 0 }
    }

    public fun increment(counter: &mut Counter) {
        counter.value = counter.value + 1;
    }

    public fun value(counter: &Counter): u64 {
        counter.value
    }

    public fun greet(name: String): String {
        let prefix = string::utf8(b"Hello, ");
        string::append(&mut prefix, name);
        prefix
    }

    public fun create_registry(): Registry {
        Registry { counters: vector::empty() }
    }

    #[test_only]
    use std::signer;

    #[test(account = @test_addr)]
    fun test_counter_increments(account: &signer) {
        let _addr = signer::address_of(account);
        let c = new_counter();
        increment(&mut c);
        increment(&mut c);
        assert!(value(&c) == 2, 0);
        let Counter { value: _ } = c;
    }

    #[test]
    fun test_new_counter_starts_at_zero() {
        let c = new_counter();
        assert!(value(&c) == 0, 1);
        let Counter { value: _ } = c;
    }

    #[test]
    fun test_greet() {
        let name = string::utf8(b"Aptos");
        let result = greet(name);
        assert!(result == string::utf8(b"Hello, Aptos"), 2);
    }
}
