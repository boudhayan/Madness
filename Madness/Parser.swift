//  Copyright (c) 2014 Rob Rix. All rights reserved.

/// Convenience for describing the types of parser combinators.
///
/// \param Tree  The type of parse tree generated by the parser.
public enum Parser<C: CollectionType, Tree> {
	/// The type of parser combinators.
	public typealias Function = (C, C.Index) -> Result

	/// The type produced by parser combinators.
	public typealias Result = Either<Error<C.Index>, (Tree, C.Index)>
}


/// Parses `input` with `parser`, returning the parse trees or `nil` if nothing could be parsed, or if parsing did not consume the entire input.
public func parse<C: CollectionType, Tree>(parser: Parser<C, Tree>.Function, input: C) -> Tree? {
	return parser(input, input.startIndex).map { $1 == input.endIndex ? $0 : nil } ?? nil
}


// MARK: - Terminals

/// Returns a parser which parses any single character.
public func any(input: String, index: String.Index) -> Parser<String, String>.Result? {
	return index < input.endIndex ? (input[index..<advance(index, 1)], index.successor()) : nil
}


/// Returns a parser which parses a `literal` sequence of elements from the input.
///
/// This overload enables e.g. `%"xyz"` to produce `String -> (String, String)`.
public prefix func % <C: CollectionType where C.Generator.Element: Equatable> (literal: C) -> Parser<C, C>.Function {
	return { input, index in
		containsAt(input, index, literal) ?
			(literal, advance(index, count(literal)))
		:	nil
	}
}


/// Returns a parser which parses a `literal` element from the input.
public prefix func % <C: CollectionType where C.Generator.Element: Equatable> (literal: C.Generator.Element) -> Parser<C, C.Generator.Element>.Function {
	return { input, index in
		index != input.endIndex && input[index] == literal ?
			(literal, index.successor())
		:	nil
	}
}


/// Returns a parser which parses any character in `interval`.
public prefix func %<I: IntervalType where I.Bound == Character>(interval: I) -> Parser<String, String>.Function {
	return { (input: String, index: String.Index) -> Parser<String, String>.Result in
		(index < input.endIndex && interval.contains(input[index])) ?
			.right(String(input[index]), index.successor())
		:	.left(.leaf("expected an element in interval \(interval)", index))
	}
}


// MARK: - Nonterminals

private func memoize<T>(f: () -> T) -> () -> T {
	var memoized: T!
	return {
		if memoized == nil {
			memoized = f()
		}
		return memoized
	}
}

public func delay<C: CollectionType, T>(parser: () -> Parser<C, T>.Function) -> Parser<C, T>.Function {
	let memoized = memoize(parser)
	return { memoized()($0, $1) }
}


// MARK: - Private

/// Returns `true` iff `collection` contains all of the elements in `needle` in-order and contiguously, starting from `index`.
func containsAt<C1: CollectionType, C2: CollectionType where C1.Generator.Element == C2.Generator.Element, C1.Generator.Element: Equatable>(collection: C1, index: C1.Index, needle: C2) -> Bool {
	let needleCount = count(needle).toIntMax()
	let range = index..<advance(index, C1.Index.Distance(needleCount), collection.endIndex)
	if count(range).toIntMax() < needleCount { return false }

	return reduce(lazy(zip(range, needle)).map { collection[$0] == $1 }, true) { $0 && $1 }
}


// MARK: - Operators

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
