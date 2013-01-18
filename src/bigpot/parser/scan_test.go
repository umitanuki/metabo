package parser

import (
	"fmt"
	"strings"
//	"testing"
)

func strLexer(input string) *lexer {
	reader := strings.NewReader(input)
	return newLexer(reader)
}

func (l *lexer) lexPrintExpect(expected int) {
	lval := &yySymType{}
	if token := l.Lex(lval); token != expected {
//		panic(fmt.Sprintf("not expected token: %d != %d", token, expected))
	}
	switch expected {
	default:
		if expected > 0 && expected < 127 {
			fmt.Printf(" %c", expected)
		} else {
			fmt.Printf(" %s", lval.str)
		}
	case ICONST:
		fmt.Printf(" %d", lval.ival)
	}
}

func ExampleLex_1() {
	lexer := strLexer("select 1")
	lexer.lexPrintExpect(IDENT)
	// Output: select
}

func ExampleLex_2() {
	lexer := strLexer("select 'foo'  /* comment */ bar")
	lexer.lexPrintExpect(IDENT)
	lexer.lexPrintExpect(SCONST)
	lexer.lexPrintExpect(IDENT)
	// Output: select foo bar
}

func ExampleLex_numbers() {
	lexer := strLexer("10 0.1e  1.53e-1")
	lexer.lexPrintExpect(ICONST)
	lexer.lexPrintExpect(FCONST)
	lexer.lexPrintExpect(IDENT)
	lexer.lexPrintExpect(FCONST)
	// Output: 10 0.1 e 1.53e-1
}

func ExampleLex_operators() {
	lexer := strLexer("1 % 2 -/* foo*/10")
	lexer.lexPrintExpect(ICONST)
	lexer.lexPrintExpect(int('%'))
	lexer.lexPrintExpect(ICONST)
	lexer.lexPrintExpect(int('-'))
	lexer.lexPrintExpect(ICONST)
	// Output: 1 % 2 - 10
}

func ExampleLex_negative1() {
	defer func() {
		if err := recover(); err != nil {
			fmt.Println("failed:", err)
		}
	} ()
	lexer := strLexer("select /* comment")
	lval := &yySymType{}
	lexer.Lex(lval)
	lexer.Lex(lval)
	// Output: failed: unterminated /* comment
}
