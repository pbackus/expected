/++
A wrapper type that bundles exceptions with return values.

The design of this module is based on C++'s proposed
[`std::expected`](https://wg21.link/p0323), and is also similar to Rust's
[`std::result`](https://doc.rust-lang.org/std/result/). See
["Expect the Expected"](https://ndcoslo.com/talk/expect-the-expected/) by
Andrei Alexandrescu for further background.

License: MIT
Author: Paul Backus
+/
module expected;

/// Basic Usage
unittest {
    import std.math: approxEqual;
    import std.exception: assertThrown;

    Expected!double relative(double a, double b)
    {
        if (a == 0) {
            return unexpected!double(
                new Exception("Division by zero")
            );
        } else {
            return expected((b - a)/a);
        }
    }

    assert(relative(2.0, 3.0).value.approxEqual(0.5));
    assert(relative(0.0, 1.0).hasValue == false);
    assertThrown(relative(0.0, 1.0).value);
}

/**
 * An `Expected!T` is either a `T` or an exception explaining why the `T` couldn't
 * be produced.
 */
struct Expected(T)
	if (!is(T == Exception))
{
private:

	import sumtype;

	SumType!(T, Exception) data;

public:

	/// Constructs an `Expected!T` with a value.
	this(T value)
	{
		data = value;
	}

	/// Constructs an `Expected!T` with an exception.
	this(Exception err)
	{
		data = err;
	}

	/// Assigns a value to an `Expected!T`.
	void opAssign(T value)
	{
		data = value;
	}

	/// Assigns an exception to an `Expected!T`.
	void opAssign(Exception err)
	{
		data = err;
	}

	/// Checks whether this `Expected!T` contains a specific value.
	bool opEquals(T rhs)
	{
		return data.match!(
			(T value) => value == rhs,
			(Exception _) => false
		);
	}

	/// Checks whether this `Expected!T` contains a specific exception.
	bool opEquals(Exception rhs)
	{
		return data.match!(
			(T _) => false,
			(Exception err) => err == rhs
		);
	}

	/// Checks whether this `Expected!T` and `rhs` contain the same value or
	/// exception.
	bool opEquals(Expected!T rhs)
	{
		return data.match!(
			(T value) => rhs == value,
			(Exception err) => rhs == err
		);
	}

	/// Checks whether this `Expected!T` contains a `T` value.
	bool hasValue()
	{
		return data.match!(
			(T value) => true,
			(Exception _) => false
		);
	}

	/// Returns the contained value if there is one, or throws the contained
	/// exception if there isn't.
	T value()
	{
		scope(failure) throw error;
		return data.tryMatch!(
			(T value) => value
		);
	}

	/// Returns the contained error.
	Exception error()
	{
		scope(failure) assert(false);
		return data.tryMatch!(
			(Exception err) => err
		);
	}

	/// Returns the contained value if there is one, or a default value if
	/// there isn't.
	T valueOr(T defaultValue)
	{
		return data.match!(
			(T value) => value,
			(Exception _) => defaultValue
		);
	}
}

// Construction
unittest {
	assert(__traits(compiles, Expected!int(123)));
	assert(__traits(compiles, Expected!int(new Exception("oops"))));
}

// Assignment
unittest {
	Expected!int x;

	assert(__traits(compiles, x = 123));
	assert(__traits(compiles, x = new Exception("oops")));
}

// Self assignment
unittest {
	Expected!int x, y;

	assert(__traits(compiles, x = y));
}

// Equality with self
unittest {
	int n = 123;
	Exception e = new Exception("oops");

	Expected!int x = n;
	Expected!int y = n;
	Expected!int z = e;
	Expected!int w = e;

	assert(x == y);
	assert(z == w);
	assert(x != z);
	assert(z != x);
}

// Equality with T and Exception
unittest {
	int n = 123;
	Exception e = new Exception("oops");

	Expected!int x = n;
	Expected!int y = e;

	assert(x == n);
	assert(y == e);
	assert(x != e);
	assert(x != 456);
	assert(y != n);
	assert(y != new Exception("oh no"));
}

// hasValue
unittest {
	Expected!int x = 123;
	Expected!int y = new Exception("oops");

	assert(x.hasValue);
	assert(!y.hasValue);
}

// value
unittest {
	import std.exception: collectException;

	Exception e = new Exception("oops");

	Expected!int x = 123;
	Expected!int y = e;

	assert(x.value == 123);
	assert(collectException(y.value) == e);
}

// error
unittest {
	import std.exception: assertThrown;
	import core.exception: AssertError;

	Exception e = new Exception("oops");

	Expected!int x = 123;
	Expected!int y = e;

	assertThrown!AssertError(x.error);
	assert(y.error == e);
}

// valueOr
unittest {
	Expected!int x = 123;
	Expected!int y = new Exception("oops");

	assert(x.valueOr(456) == 123);
	assert(y.valueOr(456) == 456);
}

/// Creates an `Expected` object from a value, with type inference
Expected!T expected(T)(T value)
{
	return Expected!T(value);
}

unittest {
	assert(__traits(compiles, expected(123)));
	assert(is(typeof(expected(123)) == Expected!int));
}

/// Creates an `Expected` object from an exception
Expected!T unexpected(T)(Exception err)
{
	return Expected!T(err);
}

unittest {
	Exception e = new Exception("oops");
	assert(__traits(compiles, unexpected!int(e)));
	assert(is(typeof(unexpected!int(e)) == Expected!int));
}
