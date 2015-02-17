//  Copyright (c) 2014 Rob Rix. All rights reserved.

/// Convenience for describing the types of parser combinators.
///
/// \param Tree  The type of parse tree generated by the parser.
public struct Parser<Tree> {
	/// The type of parser combinators.
	public typealias Function = String -> (Tree, String)?
}


/// Parses `string` with `parser`, returning the parse trees or `nil` if nothing could be parsed or if parsing did not consume the entire input.
public func parse<Tree>(parser: Parser<Tree>.Function, string: String) -> Tree? {
	return parser(string).map { $1 == "" ? $0 : nil } ?? nil
}


// MARK: - Terminals

/// Returns a parser which parses any single character.
public func any(input: String) -> (String, String)? {
	return input.isEmpty ? nil : (input.toOffset(1), input.fromOffset(1))
}


/// Returns a parser which parses `string`.
public prefix func % (string: String) -> Parser<String>.Function {
	return {
		startsWith($0, string) ?
			(string, $0.fromOffset(count(string)))
		:	nil
	}
}


/// Returns a parser which parses any character in `interval`.
public prefix func %<I: IntervalType where I.Bound == Character>(interval: I) -> Parser<String>.Function {
	return { string in
		first(string).map { interval.contains($0) ? ("" + [$0], string.fromOffset(1)) : nil } ?? nil
	}
}


// MARK: - Nonterminals

// MARK: Concatenation

/// Parses the concatenation of `left` and `right`, pairing their parse trees.
public func ++ <T, U> (left: Parser<T>.Function, right: Parser<U>.Function) -> Parser<(T, U)>.Function {
	return concatenate(left, right)
}

/// Parses the concatenation of `left` and `right`, dropping `right`’s parse tree.
public func ++ <T> (left: Parser<T>.Function, right: Parser<()>.Function) -> Parser<T>.Function {
	return concatenate(left, right) --> { x, _ in x }
}

/// Parses the concatenation of `left` and `right`, dropping `left`’s parse tree.
public func ++ <T> (left: Parser<()>.Function, right: Parser<T>.Function) -> Parser<T>.Function {
	return concatenate(left, right) --> { $1 }
}

/// Parses the concatenation of `left` and `right, dropping both parse trees.
public func ++ (left: Parser<()>.Function, right: Parser<()>.Function) -> Parser<()>.Function {
	return ignore(concatenate(left, right))
}



// MARK: Alternation

/// Parses either `left` or `right`.
public func | <T, U> (left: Parser<T>.Function, right: Parser<U>.Function) -> Parser<Either<T, U>>.Function {
	return alternate(left, right)
}

/// Parses either `left` or `right` and coalesces their trees.
public func | <T> (left: Parser<T>.Function, right: Parser<T>.Function) -> Parser<T>.Function {
	return alternate(left, right) --> { $0.either(id, id) }
}

/// Parses either `left` or `right`, dropping `right`’s parse tree.
public func | <T> (left: Parser<T>.Function, right: Parser<()>.Function) -> Parser<T?>.Function {
	return alternate(left, right) --> { $0.either(id, const(nil)) }
}

/// Parses either `left` or `right`, dropping `left`’s parse tree.
public func | <T> (left: Parser<()>.Function, right: Parser<T>.Function) -> Parser<T?>.Function {
	return alternate(left, right) --> { $0.either(const(nil), id) }
}

/// Parses either `left` or `right`, dropping both parse trees.
public func | (left: Parser<()>.Function, right: Parser<()>.Function) -> Parser<()>.Function {
	return alternate(left, right) --> { $0.either(id, id) }
}


// MARK: Repetition

/// Parses `parser` 0 or more times.
public postfix func * <T> (parser: Parser<T>.Function) -> Parser<[T]>.Function {
	return repeat(parser, 0..<Int.max)
}

/// Creates a parser from `string`, and parses it 0 or more times.
public postfix func * (string: String) -> Parser<[String]>.Function {
	return repeat(%(string), 0..<Int.max)
}

/// Parses `parser` 0 or more times and drops its parse trees.
public postfix func * (parser: Parser<()>.Function) -> Parser<()>.Function {
	return repeat(parser, 0..<Int.max) --> const(())
}

/// Parses `parser` 1 or more times.
public postfix func + <T> (parser: Parser<T>.Function) -> Parser<[T]>.Function {
	return repeat(parser, 1..<Int.max)
}

/// Creates a parser from `string`, and parses it 1 or more times.
public postfix func + (string: String) -> Parser<[String]>.Function {
	return repeat(%(string), 1..<Int.max)
}

/// Parses `parser` 0 or more times and drops its parse trees.
public postfix func + (parser: Parser<()>.Function) -> Parser<()>.Function {
	return repeat(parser, 1..<Int.max) --> const(())
}

/// Parses `parser` exactly `n` times.
///
/// `n` must be > 0 to make any sense.
public func * <T> (parser: Parser<T>.Function, n: Int) -> Parser<[T]>.Function {
	return repeat(parser, n...n)
}

/// Parses `parser` the number of times specified in `interval`.
///
/// \param interval  An interval specifying the number of repetitions to perform. `0...n` means at most `n+1` repetitions; `m...Int.max` means at least `m` repetitions; and `m...n` means between `m` and `n` repetitions (inclusive).
public func * <T> (parser: Parser<T>.Function, interval: ClosedInterval<Int>) -> Parser<[T]>.Function {
	return repeat(parser, interval)
}

/// Parses `parser` the number of times specified in `interval`.
///
/// \param interval  An interval specifying the number of repetitions to perform. `0..<n` means at most `n` repetitions; `m..<Int.max` means at least `m` repetitions; and `m..<n` means at least `m` and fewer than `n` repetitions.
public func * <T> (parser: Parser<T>.Function, interval: HalfOpenInterval<Int>) -> Parser<[T]>.Function {
	return repeat(parser, interval)
}


// MARK: Mapping

/// Returns a parser which maps parse trees into another type.
public func --> <T, U>(parser: Parser<T>.Function, f: T -> U) -> Parser<U>.Function {
	return {
		parser($0).map { (f($0), $1) }
	}
}


// MARK: Ignoring input

/// Ignores any parse trees produced by `parser`.
public func ignore<T>(parser: Parser<T>.Function) -> Parser<()>.Function {
	return parser --> const(())
}

/// Ignores any parse trees produced by a parser which parses `string`.
public func ignore(string: String) -> Parser<()>.Function {
	return ignore(%string)
}


// MARK: Binding

/// Returns a parser which requires `parser` to parse, passes its parsed trees to a function `f`, and then requires the result of `f` to parse.
///
/// This can be used to conveniently make a parser which depends on earlier parsed input, for example to parse exactly the same number of characters, or to parse structurally significant indentation.
public func >>- <T, U> (parser: Parser<T>.Function, f: T -> Parser<U>.Function) -> Parser<U>.Function {
	return {
		parser($0).map { f($0)($1) } ?? nil
	}
}


// MARK: Private

/// Defines concatenation for use in the `++` operator definitions above.
private func concatenate<T, U>(left: Parser<T>.Function, right: Parser<U>.Function) -> Parser<(T, U)>.Function {
	return {
		left($0).map { x, rest in
			right(rest).map { y, rest in
				((x, y), rest)
			}
		} ?? nil
	}
}


/// Defines alternation for use in the `|` operator definitions above.
private func alternate<T, U>(left: Parser<T>.Function, right: Parser<U>.Function) -> Parser<Either<T, U>>.Function {
	return {
		left($0).map { (.left($0), $1) } ?? right($0).map { (.right($0), $1) }
	}
}


/// Defines repetition for use in the postfix `*` and `+` operator definitions above.
private func repeat<T>(parser: Parser<T>.Function, _ interval: ClosedInterval<Int> = 0...Int.max) -> Parser<[T]>.Function {
	if interval.end <= 0 { return { ([], $0) } }
	
	return { input in
		parser(input).map { first, rest in
			repeat(parser, (interval.start - 1)...(interval.end - (interval.end == Int.max ? 0 : 1)))(rest).map {
				([first] + $0, $1)
			}
		} ?? (interval.start <= 0 ? ([], input) : nil)
	}
}
private func repeat<T>(parser: Parser<T>.Function, _ interval: HalfOpenInterval<Int> = 0..<Int.max) -> Parser<[T]>.Function {
	if interval.isEmpty { return { _ -> ([T], String)? in nil } }
	return repeat(parser, ClosedInterval(interval.start, interval.end.predecessor()))
}


// MARK: - Operators

/// Concatenation operator.
infix operator ++ {
	/// Associates to the right, linked-list style.
	associativity right

	/// Higher precedence than |.
	precedence 160
}


/// Zero-or-more repetition operator.
postfix operator * {}

/// One-or-more repetition operator.
postfix operator + {}


/// Map operator.
infix operator --> {
	/// Associates to the left.
	associativity left

	/// Lower precedence than |.
	precedence 100
}


/// Literal operator.
prefix operator % {}


/// Bind operator.
infix operator >>- {
	associativity left
	precedence 150
}


// MARK: - Imports

import Either
import Prelude
