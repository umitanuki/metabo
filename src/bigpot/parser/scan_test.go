package parser

import (
	"fmt"
	"strings"
)

func strLexer(input string) *lexer {
	reader := strings.NewReader(input)
	return newLexer(reader)
}

func (l *lexer) lexPrintExpect(expected int) {
	lval := &yySymType{}
	if token := l.Lex(lval); token != expected {
		fmt.Printf("not expected token: %d != %d", token, expected)
		return
	}
	switch expected {
	default:
		if expected > 0 && expected < 127 {
			fmt.Printf(" %c", expected)
		} else if expected > COLON_EQUALS { /* too hacky... */
			fmt.Printf(" %s", lval.keyword)
		} else {
			fmt.Printf(" %s", lval.str)
		}
	case ICONST, PARAM:
		fmt.Printf(" %d", lval.ival)
	}
}

func recoverPanic() {
	if err := recover(); err != nil {
		fmt.Println("failed:", err)
	}
}

func ExampleLex_1() {
	lexer := strLexer("select 1")
	lexer.lexPrintExpect(SELECT)
	// Output: select
}

func ExampleLex_2() {
	lexer := strLexer("select 'foo'  /* comment */ bar")
	lexer.lexPrintExpect(SELECT)
	lexer.lexPrintExpect(SCONST)
	lexer.lexPrintExpect(IDENT)
	// Output: select foo bar
}

func ExampleLex_numbers() {
	lexer := strLexer("10 0.1e  1.53e-1 1.  0001.999 9999999999999999999")
	lexer.lexPrintExpect(ICONST)
	lexer.lexPrintExpect(FCONST)
	lexer.lexPrintExpect(IDENT)
	lexer.lexPrintExpect(FCONST)
	lexer.lexPrintExpect(FCONST)
	lexer.lexPrintExpect(FCONST)
	lexer.lexPrintExpect(FCONST)
	// Output: 10 0.1 e 1.53e-1 1. 0001.999 9999999999999999999
}

func ExampleLex_operators() {
	lexer := strLexer("1 % 2 -/* foo*/10 <> !=")
	lexer.lexPrintExpect(ICONST)
	lexer.lexPrintExpect(int('%'))
	lexer.lexPrintExpect(ICONST)
	lexer.lexPrintExpect(int('-'))
	lexer.lexPrintExpect(ICONST)
	lexer.lexPrintExpect(Op)
	lexer.lexPrintExpect(Op)
	// Output: 1 % 2 - 10 <> <>
}

func ExampleLex_params() {
	lexer := strLexer("$1 $0")
	lexer.lexPrintExpect(PARAM)
	lexer.lexPrintExpect(PARAM)
	// Output: 1 0
}

func ExampleLex_negative1() {
	defer recoverPanic()
	lexer := strLexer("select /* comment")
	lval := &yySymType{}
	lexer.Lex(lval)
	lexer.Lex(lval)
	// Output: failed: unterminated /* comment
}

func ExampleLex_params_negative() {
	defer recoverPanic()
	lexer := strLexer("$99999999999999999999999999999")
	lexer.lexPrintExpect(PARAM)
	// Output: failed: value out of range for param
}
