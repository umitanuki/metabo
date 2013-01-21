%{
package parser

import (
	"fmt"
	"io"
	"strconv"
	"strings"
)

type lexer struct {
	reader io.RuneReader
	cond int
	current rune
	pos int
	buf []rune
	literalbuf []rune

	lesspos int
	lessbuf []rune

	dolqstart string
}

func newLexer(source io.RuneReader) *lexer {
	return &lexer{reader: source}
}

func (l *lexer) next() rune {
	if l.current != 0 {
		l.buf = append(l.buf, l.current)
	}
	l.current = 0

	if len(l.lessbuf) > 0 {
		l.current = l.lessbuf[l.lesspos]
		l.lesspos++
		if l.lesspos >= len(l.lessbuf) {
			l.lessbuf = nil
			l.lesspos = 0
		}
	} else if r, _, e := l.reader.ReadRune(); e == nil {
		l.current = r
	}

	//fmt.Printf("ret: %c\n", l.current)
	return l.current
}

func (l *lexer) clearBuf() {
	l.buf = l.buf[:0]
}

func (l *lexer) startLiteral() {
	l.literalbuf = l.literalbuf[:0]
}

func (l *lexer) addLiteralRune(lit rune) {
	l.literalbuf = append(l.literalbuf, lit)
}

func (l *lexer) addLiteral(lits []rune) {
	l.literalbuf = append(l.literalbuf, lits...)
}

func (l *lexer) getBuf() string {
	return string(l.buf)
}

/* Returns all but first n chars to a buffer for rescanning later */
func (l *lexer) yyless(n int) {
	/*
	 * If lessbuf is not empty, we haven't read a new rune from reader yet.
	 */
	if l.lessbuf != nil {
		l.lesspos -= n
		l.current = 0
		return
	}

	/*
	 * Otherwise copy trailing buffer.
	 */
	l.lessbuf = l.buf[n:]
	l.lessbuf = append(l.lessbuf, l.current)
	l.buf = l.buf[:n]
	l.lesspos = 0
	l.current = 0
}

func (l *lexer) SET_YYLLOC() {
	/* not implemented */
}

func (l *lexer) BEGIN(cond int) {
	l.cond = cond
	l.clearBuf()
}

func (l *lexer) Error(e string) {
	panic(e)
}

func (l *lexer) Lex(lval *yySymType) int {
	const (
		INITIAL = iota
		xb
		xc
		xd
		xh
		xe
		xq
		xdolq
	)

	/* Start with the last characher we scanned. */
	c := l.current

	if c == 0 {
		/* But get next if not scanned (e.g. the very first time). */
		c = l.next()
	}
	xcdepth := 0
%}

%yyc c
%yyn c = l.next()
%yyt l.cond

/*
 * OK, here is a short description of lex/flex rules behavior.
 * The longest pattern which matches an input string is always chosen.
 * For equal-length patterns, the first occurring in the rules list is chosen.
 * INITIAL is the starting state, to which all non-conditional rules apply.
 * Exclusive states change parsing rules while the state is active.  When in
 * an exclusive state, only those rules defined for that state apply.
 *
 * We use exclusive states for quoted strings, extended comments,
 * and to eliminate parsing troubles for numeric strings.
 * Exclusive states:
 *  <xb> bit string literal
 *  <xc> extended C-style comments
 *  <xd> delimited identifiers (double-quoted identifiers)
 *  <xh> hexadecimal numeric string
 *  <xq> standard quoted strings
 *  <xe> extended quoted strings (support backslash escape sequences)
 *  <xdolq> $foo$ quoted strings
 *  <xui> quoted identifier with Unicode escapes
 *  <xus> quoted string with Unicode escapes
 *  <xeu> Unicode surrogate escape in extended string
 */

%x xb
%x xc
%x xd
%x xh
%x xe
%x xq
%x xdolq
/*
%x xui
%x xus
%x xeu
*/

/*
 * In order to make the world safe for Windows and Mac clients as well as
 * Unix ones, we accept either \n or \r as a newline.  A DOS-style \r\n
 * sequence will be seen as two successive newlines, but that doesn't cause
 * any problems.  Comments that start with -- and extend to the next
 * newline are treated as equivalent to a single whitespace character.
 *
 * NOTE a fine point: if there is no newline following --, we will absorb
 * everything to the end of the input as a comment.  This is correct.  Older
 * versions of Postgres failed to recognize -- as a comment if the input
 * did not end with a newline.
 *
 * XXX perhaps \f (formfeed) should be treated as a newline as well?
 *
 * XXX if you change the set of whitespace characters, fix scanner_isspace()
 * to agree, and see also the plpgsql lexer.
 */

space			[ \t\n\r\f]
horiz_space		[ \t\f]
newline			[\n\r]
non_newline		[^\n\r]

comment			("--"{non_newline}*)

whitespace		({space}+|{comment})

/*
 * SQL requires at least one newline in the whitespace separating
 * string literals that are to be concatenated.  Silly, but who are we
 * to argue?  Note that {whitespace_with_newline} should not have * after
 * it, whereas {whitespace} should generally have a * after it...
 */

special_whitespace		({space}+|{comment}{newline})
horiz_whitespace		({horiz_space}|{comment})
whitespace_with_newline	({horiz_whitespace}*{newline}{special_whitespace}*)

/*
 * To ensure that {quotecontinue} can be scanned without having to back up
 * if the full pattern isn't matched, we include trailing whitespace in
 * {quotestop}.  This matches all cases where {quotecontinue} fails to match,
 * except for {quote} followed by whitespace and just one "-" (not two,
 * which would start a {comment}).  To cover that we have {quotefail}.
 * The actions for {quotestop} and {quotefail} must throw back characters
 * beyond the quote proper.
 */
quote			'
quotestop		{quote}{whitespace}*
quotecontinue	{quote}{whitespace_with_newline}{quote}
quotefail		{quote}{whitespace}*"-"

/* Bit string
 * It is tempting to scan the string for only those characters
 * which are allowed. However, this leads to silently swallowed
 * characters if illegal characters are included in the string.
 * For example, if xbinside is [01] then B'ABCD' is interpreted
 * as a zero-length string, and the ABCD' is lost!
 * Better to pass the string forward and let the input routines
 * validate the contents.
 */
xbstart			[bB]{quote}
xbinside		[^']*

/* Hexadecimal number */
xhstart			[xX]{quote}
xhinside		[^']*

/* Quoted string that allows backslash escapes */
xestart			[eE]{quote}
xeinside		[^\\']+
xeescape		[\\][^0-7]
xeoctesc		[\\][0-7]{1,3}
xehexesc		[\\]x[0-9A-Fa-f]{1,2}
xeunicode		[\\](u[0-9A-Fa-f]{4}|U[0-9A-Fa-f]{8})
xeunicodebad	[\\]([uU])

/*
 * Extended quote
 * xqdouble implements embedded quote, ''''
 */
xqstart			{quote}
xqdouble		{quote}{quote}
xqinside		[^']+

/* $foo$ style quotes ("dollar quoting")
 * The quoted string starts with $foo$ where "foo" is an optional string
 * in the form of an identifier, except that it may not contain "$", 
 * and extends to the first occurrence of an identical string.  
 * There is *no* processing of the quoted text.
 *
 * {dolqfailed} is an error rule to avoid scanner backup when {dolqdelim}
 * fails to match its trailing "$".
 */
dolq_start		[A-Za-z\200-\377_]
dolq_cont		[A-Za-z\200-\377_0-9]
dolqdelim		\$({dolq_start}{dolq_cont}*)?\$
dolqfailed		\${dolq_start}{dolq_cont}*
dolqinside		[^$]+

/* Double quote
 * Allows embedded spaces and other special characters into identifiers.
 */
dquote			\"
xdstart			{dquote}
xdstop			{dquote}
xddouble		{dquote}{dquote}
xdinside		[^"]+

/* Unicode escapes */
uescape			[uU][eE][sS][cC][aA][pP][eE]{whitespace}*{quote}[^']{quote}
/* error rule to avoid backup */
uescapefail		("-"|[uU][eE][sS][cC][aA][pP][eE]{whitespace}*"-"|[uU][eE][sS][cC][aA][pP][eE]{whitespace}*{quote}[^']|[uU][eE][sS][cC][aA][pP][eE]{whitespace}*{quote}|[uU][eE][sS][cC][aA][pP][eE]{whitespace}*|[uU][eE][sS][cC][aA][pP]|[uU][eE][sS][cC][aA]|[uU][eE][sS][cC]|[uU][eE][sS]|[uU][eE]|[uU])

/* Quoted identifier with Unicode escapes */
/*
xuistart		[uU]&{dquote}
xuistop1		{dquote}{whitespace}*{uescapefail}?
xuistop2		{dquote}{whitespace}*{uescape}
*/

/* Quoted string with Unicode escapes */
/*
xusstart		[uU]&{quote}
xusstop1		{quote}{whitespace}*{uescapefail}?
xusstop2		{quote}{whitespace}*{uescape}
*/

/* error rule to avoid backup */
xufailed		[uU]&


/* C-style comments
 *
 * The "extended comment" syntax closely resembles allowable operator syntax.
 * The tricky part here is to get lex to recognize a string starting with
 * slash-star as a comment, when interpreting it as an operator would produce
 * a longer match --- remember lex will prefer a longer match!  Also, if we
 * have something like plus-slash-star, lex will think this is a 3-character
 * operator whereas we want to see it as a + operator and a comment start.
 * The solution is two-fold:
 * 1. append {op_chars}* to xcstart so that it matches as much text as
 *    {operator} would. Then the tie-breaker (first matching rule of same
 *    length) ensures xcstart wins.  We put back the extra stuff with yyless()
 *    in case it contains a star-slash that should terminate the comment.
 * 2. In the operator rule, check for slash-star within the operator, and
 *    if found throw it back with yyless().  This handles the plus-slash-star
 *    problem.
 * Dash-dash comments have similar interactions with the operator rule.
 */
xcstart			\/\*{op_chars}*
xcstop			\*+\/
xcinside		[^*/]+

digit			[0-9]
ident_start		[A-Za-z\200-\377_]
ident_cont		[A-Za-z\200-\377_0-9\$]

identifier		{ident_start}{ident_cont}*

typecast		"::"

/*
 * "self" is the set of chars that should be returned as single-character
 * tokens.  "op_chars" is the set of chars that can make up "Op" tokens,
 * which can be one or more characters long (but if a single-char token
 * appears in the "self" set, it is not to be returned as an Op).  Note
 * that the sets overlap, but each has some chars that are not in the other.
 *
 * If you change either set, adjust the character lists appearing in the
 * rule for "operator"!
 */
self			[\-,()\[\].;\:\+\*\/\%\^\<\>\=]
op_chars		[\-\~\!\@\#\^\&\|\`\?\+\*\/\%\<\>\=]
operator		{op_chars}+

/* we no longer allow unary minus in numbers. 
 * instead we pass it separately to parser. there it gets
 * coerced via doNegate() -- Leon aug 20 1999
 *
 * {realfail1} and {realfail2} are added to prevent the need for scanner
 * backup when the {real} rule fails to match completely.
 */

integer			{digit}+
decimal			(({digit}*\.{digit}+)|({digit}+\.{digit}*))
real			({integer}|{decimal})[Ee][-+]?{digit}+
realfail1		({integer}|{decimal})[Ee]
realfail2		({integer}|{decimal})[Ee][-+]

param			\${integer}

other			.

/*
 * Dollar quoted strings are totally opaque, and no escaping is done on them.
 * Other quoted strings must allow some special characters such as single-quote
 *  and newline.
 * Embedded single-quotes are implemented both in the SQL standard
 *  style of two adjacent single quotes "''" and in the Postgres/Java style
 *  of escaped-quote "\'".
 * Other embedded escaped characters are matched explicitly and the leading
 *  backslash is dropped from the string.
 * Note that xcstart must appear before operator, as explained above!
 *  Also whitespace (comment) must appear before operator.
 */

%%

	l.clearBuf()

{whitespace}
	/* ignore */

{xcstart}
	xcdepth = 0
	l.BEGIN(xc)

<xc>{xcstart}
	xcdepth++

<xc>{xcstop}
	if xcdepth <= 0 {
		l.BEGIN(INITIAL)
	} else {
		xcdepth--
	}

<xc>{xcinside}
	/* ignore */

<xc>{op_chars}
	/* ignore */

<xc>\*+
	/* ignore */

<xc>\0
	l.Error("unterminated /* comment")

{xbstart}
	/*
	 * Binary bit type.
	 * At some point we should simply pass the string
	 * forward to the parser and label it there.
	 * In the meantime, place a leading "b" on the string
	 * to mark it for the input routine as a binary string.
	 */
	l.SET_YYLLOC()
	l.BEGIN(xb)
	l.startLiteral()
	l.addLiteralRune('b')

<xb>{quotestop} |
<xb>{quotefail}
	l.yyless(1)
	l.BEGIN(INITIAL)
	lval.str = string(l.literalbuf)
	return BCONST

<xh>{xhinside} |
<xb>{xbinside}
	l.addLiteral(l.buf)

<xh>{quotecontinue} |
<xb>{quotecontinue}
	/* ignore */

<xb>\0
	l.Error("unterminated bit string literal")

{xhstart}
	/*
	 * Hexadecimal bit type.
	 * At some point we should simply pass the string
	 * forward to the parser and label it there.
	 * In the meantime, place a leading "x" on the string
	 * to mark it for the input routine as a hex string.
	 */
	l.SET_YYLLOC()
	l.BEGIN(xh)
	l.startLiteral()
	l.addLiteralRune('x')

<xh>{quotestop} |
<xh>{quotefail}
	l.yyless(1)
	l.BEGIN(INITIAL)
	lval.str = string(l.literalbuf)
	return XCONST

<xh>\0
	l.Error("unterminated hexadecimal string literal")

{xqstart}
	l.SET_YYLLOC()
	l.BEGIN(xq)
	l.startLiteral()

{xestart}
	l.BEGIN(xe)

<xq,xe>{quotestop} |
<xq,xe>{quotefail}
	l.yyless(1)
	l.BEGIN(INITIAL)
	lval.str = string(l.literalbuf)
	return SCONST

<xq,xe>{xqdouble}

<xq>{xqinside}
	l.addLiteral(l.buf)

<xe>{xeinside}


{dolqdelim}
	l.SET_YYLLOC()
	l.dolqstart = l.getBuf()
	l.BEGIN(xdolq)
	l.startLiteral()

{dolqfailed}
	l.SET_YYLLOC()
	l.yyless(1)
	return int(l.buf[0])

<xdolq>{dolqdelim}
	if l.getBuf() == l.dolqstart {
		l.dolqstart = ""
		l.BEGIN(INITIAL)
		lval.str = string(l.literalbuf)
		return SCONST
	} else {
		/*
		 * When we fail to match $...$ to dolqstart, transfer
		 * the $... part to the output, but put back the final
		 * $ for rescanning.  Consider $delim$...$junk$delim$
		 */
		yyleng := len(l.buf)
		l.addLiteral(l.buf[:yyleng-1])
		l.yyless(yyleng - 1)
	}

<xdolq>{dolqinside}
	l.addLiteral(l.buf)

<xdolq>{dolqfailed}
	l.addLiteral(l.buf)

<xdolq>.
	/* This is only needed for $ inside the quoted text */
	l.addLiteralRune(l.buf[0])

<xdolq>\0
	l.Error("unterminated dollar-quoted string")

{xdstart}
	l.SET_YYLLOC()
	l.BEGIN(xd)
	l.startLiteral()

<xd>{xdstop}
	l.BEGIN(INITIAL)
	if len(l.literalbuf) == 0 {
		l.Error("zero-length delimited identifier")
	}
	ident := string(l.literalbuf)
	/* TODO: NAMEDATALEN */
	/*
	if (yyextra->literallen >= NAMEDATALEN)
		truncate_identifier(ident, yyextra->literallen, true);
	*/
	lval.str = ident
	return IDENT

<xd>{xddouble}
	l.addLiteralRune('"')

<xd>{xdinside}
	l.addLiteral(l.buf)

<xd>\0
	l.Error("unterminated quoted identifier")

{typecast}
	l.SET_YYLLOC()
	return TYPECAST

	/*
	{dot_dot}
		l.SET_YYLLOC()
		return DOT_DOT

	{colon_equals}
		l.SET_YYLLOC()
		return COLON_EQUALS
	*/

{self}
	l.SET_YYLLOC()
	return int(l.buf[0])

{operator}
	/* TODO: rethink rune vs byte */
	yystr := l.getBuf()
	nchars := len(yystr)
	slashstar := strings.Index(yystr, "/*")
	dashdash := strings.Index(yystr, "--")

	if slashstar > -1 && dashdash > -1 {
		/* if both appear, take the first one */
		if slashstar > dashdash {
			slashstar = dashdash
		}
	} else if slashstar < 0 {
		slashstar = dashdash
	}

	if slashstar > -1 {
		nchars = slashstar
	}

	/*
	 * For SQL compatibility, '+' and '-' cannot be the
	 * last char of a multi-char operator unless the operator
	 * contains chars that are not in SQL operators.
	 * The idea is to lex '=-' as two operators, but not
	 * to forbid operator names like '?-' that could not be
	 * sequences of SQL operators.
	 */
	for nchars > 1 && (yystr[nchars - 1] == '+' || yystr[nchars - 1] == '-') {

		if strings.IndexAny(yystr[:nchars-1], "~!@#^&|`?%") > -1 {
			break
		}
		/*
		var ic int

		for ic = nchars - 2; ic >= 0; ic-- {
			if strings.IndexRune("~!@#^&|`?%", yystr[ic]) > -1 {
				break
			}
		}
		if ic >= 0 {
			break
		}
		*/
		nchars--
	}

	l.SET_YYLLOC()
	if nchars < len(yystr) {
		/* Strip the unwanted chars from the token */
		l.yyless(nchars)

		/* After yyless, form the string again. */
		yystr = l.getBuf()
		/*
		 * If what we have left is only one char, and it's
		 * one of the characters matching "self", then
		 * return it as a character token the same way
		 * that the "self" rule would have.
		 */
		if nchars == 1 && strings.Contains(",()[].;:+-*/%^<>=", yystr[0:0]) {
			return int(yystr[0])
		}
	}

	/*
	 * Complain if operator is too long.  Unlike the case
	 * for identifiers, we make this an error not a notice-
	 * and-truncate, because the odds are we are looking at
	 * a syntactic mistake anyway.
	 */
	/*
	 * TODO:
	if (nchars >= NAMEDATALEN)
		yyerror("operator too long");
	 */

	/* Convert "!=" operator to "<>" for compatibility */
	if yystr == "!=" {
		lval.str = "<>"
	} else {
		lval.str = yystr
	}
	return Op

{param}
	l.SET_YYLLOC()
	if val, err := strconv.Atoi(l.getBuf()[1:]); err == nil {
		lval.ival = val
		return PARAM
	}
	l.Error("value out of range for param")

{integer}
	l.SET_YYLLOC()
	if val, err := strconv.Atoi(l.getBuf()); err == nil {
		lval.ival = val
		return ICONST
	}
	lval.str = l.getBuf()
	return FCONST

{decimal}
	l.SET_YYLLOC()
	lval.str = l.getBuf()
	return FCONST

{real}
	l.SET_YYLLOC()
	lval.str = l.getBuf()
	return FCONST

{realfail1}
	/*
	 * throw back the [Ee]
	 */
	l.yyless(len(l.buf) - 1)
	l.SET_YYLLOC()
	lval.str = l.getBuf()
	return FCONST

{realfail2}
	/*
	 * throw back the [Ee][+-]
	 */
	l.yyless(len(l.buf) - 2)
	lval.str = l.getBuf()
	return FCONST

{identifier}
	yystr := l.getBuf()
	l.SET_YYLLOC()
	/*
	 * If this is a keyword, return the token number instead of IDENT
	 */
	if keyword, err := findKeyword(yystr); err == nil {
		lval.keyword = keyword.name
		return keyword.token
	}
	lval.str = strings.ToLower(yystr)
	lval.str = yystr
	return IDENT

{other}
	l.SET_YYLLOC()
	return int(l.buf[0])

\0
	l.SET_YYLLOC()
	return 0
	//return yyEofCode


%%
	panic("scanner panic")
}

