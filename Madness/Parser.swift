//  Copyright (c) 2014 Rob Rix. All rights reserved.

/// Convenience for describing the types of parser combinators.
///
/// \param Tree  The type of parse tree generated by the parser.
public struct Parser<Tree> {
	/// The type of parser combinators.
	public typealias Function = String -> (Tree, String)?
}


// MARK: - Terminals

/// Returns a parser which parses `string`.
public prefix func % (string: String) -> Parser<String>.Function {
	return {
		startsWith($0, string) ?
			(string, $0.fromOffset(countElements(string)))
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
	return repeat(parser)
}

/// Parses `parser` 0 or more times and drops its parse trees.
public postfix func * (parser: Parser<()>.Function) -> Parser<()>.Function {
	return repeat(parser) --> const(())
}

/// Parses `parser` 1 or more times.
public postfix func + <T> (parser: Parser<T>.Function) -> Parser<[T]>.Function {
	return repeat(parser, 1..<Int.max)
}

/// Parses `parser` 0 or more times and drops its parse trees.
public postfix func + (parser: Parser<()>.Function) -> Parser<()>.Function {
	return repeat(parser, 1..<Int.max) --> const(())
}

/// Parses `parser` exactly `n` times.
///
/// `n` must be > 0 to make any sense.
public func * <T> (parser: Parser<T>.Function, n: Int) -> Parser<[T]>.Function {
	return repeat(parser, n..<n)
}

/// Parses `parser` the number of times specified in `interval`.
///
/// \param interval  An interval specifying the number of repetitions to perform. `0..<n` means at most `n` repetitions; `m..<Int.max` means at least `m` repetitions; and `m..<n` means between `m` and `n` repetitions.
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
private func repeat<T>(parser: Parser<T>.Function, _ interval: HalfOpenInterval<Int> = 0..<Int.max) -> Parser<[T]>.Function {
	if interval.end <= 0 { return { ([], $0) } }

	return { input in
		parser(input).map { first, rest in
			repeat(parser, (interval.start - 1)..<(interval.end - (interval.end == Int.max ? 0 : 1)))(rest).map {
				([first] + $0, $1)
			}
		} ?? (interval.start <= 0 ? ([], input) : nil)
	}
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


// MARK: - Imports

import Either
import Prelude
