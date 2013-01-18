%{

package parser

import (
	"fmt"
)

type Node struct {

}

%}

%union{
	node   *Node
	str		string
	ival	int
	keyword	string
}

%token

%left	'-' '+'
%left	'*' '/'

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
%token <str> IDENT FCONST SCONST Op
%token <ival> ICONST PARAM
%token        TYPECAST DOT_DOT COLON_EQUALS

%token <keyword> SELECT

%%
statements: /* empty */
		| statements ';' statement
;

statement:
	{
		$$ = &Node{}
	}
%%
