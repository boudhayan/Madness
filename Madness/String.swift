//
//  String.swift
//  Madness
//
//  Created by Josh Vera on 10/19/15.
//  Copyright © 2015 Rob Rix. All rights reserved.
//

import Foundation

public typealias CharacterParser = Parser<String.CharacterView, Character>.Function
public typealias CharacterArrayParser = Parser<String.CharacterView, [Character]>.Function
public typealias StringParser = Parser<String.CharacterView, String>.Function
public typealias DoubleParser = Parser<String.CharacterView, Double>.Function

public typealias IntParser = Parser<String.CharacterView, Int>.Function

private func maybePrepend<T>(_ value: T?) -> ([T]) -> [T] {
	return { value != nil ? [value!] + $0 : $0 }
}

private func concat<T>(_ value: [T]) -> ([T]) -> [T] {
	return { value + $0 }
}

private func concat2<T>(_ value: [T]) -> ([T]) -> ([T]) -> [T] {
	return { value2 in { value + value2 + $0 } }
}

private let someDigits: CharacterArrayParser = some(digit)

// Parses integers as an array of characters
public let int: CharacterArrayParser = {
	let minus: Parser<String.CharacterView, Character?>.Function = char("-")|?
	
	return maybePrepend <^> minus <*> someDigits
}()

private let decimal: CharacterArrayParser = prepend <^> %"." <*> someDigits

private let exp: StringParser = %"e+" <|> %"e-" <|> %"e" <|> %"E+" <|> %"E-" <|> %"E"

private let exponent: CharacterArrayParser = { s in { s.characters + $0 } } <^> exp <*> someDigits

// Parses floating point numbers as doubles
public let number: DoubleParser = { characters in Double(String(characters))! } <^>
	((concat2 <^> int <*> decimal <*> exponent)
	<|> (concat <^> int <*> decimal)
	<|> (concat <^> int <*> exponent)
	<|> int)

public let digit: CharacterParser = oneOf("0123456789")

public let space: CharacterParser = char(" ")

public let newline: CharacterParser = char("\n")

public let cr = char("\r")

public let crlf: CharacterParser = char("\r\n")

public let endOfLine: CharacterParser = newline <|> crlf

public let tab: CharacterParser = char("\t")

public func oneOf(_ input: String) -> CharacterParser {
	return satisfy { input.characters.contains($0) }
}

public func noneOf(_ input: String) -> CharacterParser {
	return satisfy { !input.characters.contains($0) }
}

public func char(_ input: Character) -> CharacterParser {
	return satisfy { $0 == input }
}
