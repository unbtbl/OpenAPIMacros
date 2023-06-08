import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import OpenAPIMacros

//let testMacros: [String: Macro.Type] = [
//    "stringify": ModelMacro.self,
//]
//
//final class ModelTests: XCTestCase {
//    func testMacro() {
//        assertMacroExpansion(
//            """
//            #stringify(a + b)
//            """,
//            expandedSource: """
//            (a + b, "a + b")
//            """,
//            macros: testMacros
//        )
//    }
//
//    func testMacroWithStringLiteral() {
//        assertMacroExpansion(
//            #"""
//            #stringify("Hello, \(name)")
//            """#,
//            expandedSource: #"""
//            ("Hello, \(name)", #""Hello, \(name)""#)
//            """#,
//            macros: testMacros
//        )
//    }
//}
