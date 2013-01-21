%{

package parser

import (
	"fmt"
	"strings"
)

type Node interface {

}

type ResTarget struct {
	name	string
}

type ParseTable struct {
	name	string
}

type SelectStmt struct {
	target	 []*ResTarget
	from	 []*ParseTable
}

var TopList []Node
%}

%union{
	node	Node
	list  []Node
	str		string
	ival	int
	keyword	string
}

%token

%left	'-' '+'
%left	'*' '/'

%type <list> statements column_list table_list
%type <node> statement

/*
 * Non-keyword token types.  These are hard-wired into the "flex" lexer.
 * They must be listed first so that their numeric codes do not depend on
 * the set of keywords.  PL/pgsql depends on this so that it can share the
 * same lexer.  If you add/change tokens here, fix PL/pgsql to match!
 *
 * TODO: Do we need DOT_DOT and COLON_EQUALS?
 * DOT_DOT is unused in the core SQL grammar, and so will always provoke
 * parse errors.  It is needed by PL/pgsql.
 */
%token <str> IDENT FCONST SCONST BCONST XCONST Op
%token <ival> ICONST PARAM
%token        TYPECAST DOT_DOT COLON_EQUALS

%token <keyword> FROM SELECT

%%
statements: /* empty */
	{
		$$ = nil
	}
		| statement
	{
		$$ = append(make([]Node, 0), $1)
		TopList = $$
	}
		| statements ';' statement
	{
		$$ = append($1, $3)
		TopList = $$
	}
;

statement: SELECT column_list FROM table_list
	{
		target := make([]*ResTarget, len($2), len($2))
		for i, elem := range $2 {
			target[i] = elem.(*ResTarget)
		}
		from := make([]*ParseTable, len($4), len($4))
		for i, elem := range $4 {
			from[i] = elem.(*ParseTable)
		}
		$$ = &SelectStmt{
			target: target,
			from: from,
		}
	}

column_list: IDENT
	{
		n := &ResTarget{name: $1}
		$$ = append(make([]Node, 0), Node(n))
	}
		| column_list ',' IDENT
	{
		n := &ResTarget{name: $3}
		$$ = append($1, Node(n))
	}

table_list: IDENT
	{
		n := &ParseTable{name: $1}
		$$ = append(make([]Node, 0), Node(n))
	}
		| table_list ',' IDENT
	{
		n := &ParseTable{name: $3}
		$$ = append($1, Node(n))
	}
%%

func ExParse(query string) Node {
	reader := strings.NewReader(query)
	lexer := newLexer(reader)
	yyParse(lexer)
	return TopList[0]
}
