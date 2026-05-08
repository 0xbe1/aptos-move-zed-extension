/// Prover module — exercises Move Prover spec blocks and invariants.
/// Open this file and run "Move: Run Move Prover on Current Module" from the command palette.
module test_addr::prover {

    struct BoundedCounter has key, store {
        value: u64,
        max: u64,
    }

    spec BoundedCounter {
        invariant value <= max;
    }

    public fun new(max: u64): BoundedCounter {
        BoundedCounter { value: 0, max }
    }

    spec new(max: u64): BoundedCounter {
        ensures result.value == 0;
        ensures result.max == max;
    }

    public fun increment(counter: &mut BoundedCounter) {
        if (counter.value < counter.max) {
            counter.value = counter.value + 1;
        }
    }

    spec increment(counter: &mut BoundedCounter) {
        ensures counter.max == old(counter.max);
        ensures counter.value <= counter.max;
        ensures old(counter.value) < old(counter.max) ==>
            counter.value == old(counter.value) + 1;
        ensures old(counter.value) >= old(counter.max) ==>
            counter.value == old(counter.value);
    }

    public fun reset(counter: &mut BoundedCounter) {
        counter.value = 0;
    }

    spec reset(counter: &mut BoundedCounter) {
        ensures counter.value == 0;
        ensures counter.max == old(counter.max);
    }

    public fun value(counter: &BoundedCounter): u64 {
        counter.value
    }

    spec value(counter: &BoundedCounter): u64 {
        ensures result == counter.value;
    }

    #[test]
    fun test_bounded_increment() {
        let c = new(3);
        increment(&mut c);
        increment(&mut c);
        increment(&mut c);
        increment(&mut c); // should be clamped at 3
        assert!(value(&c) == 3, 0);
        let BoundedCounter { value: _, max: _ } = c;
    }
}
