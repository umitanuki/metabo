package parser

import (
	. "launchpad.net/gocheck"
	"testing"
)

// Hook up gocheck into the gotest runner.
func Test(t *testing.T) {
	TestingT(t)
}

type MySuite struct{}
var _ = Suite(&MySuite{})
func (s *MySuite) TestYYParse_1(c *C) {
	query := "  select col1, col2 FROM tab1"
	lexer := strLexer(query)
	yyParse(lexer)
	node, ok := TopList[0].(*SelectStmt)
	if !ok {
		c.Error("node is not SelectStmt")
	}
	c.Check(node.target[0].name, Equals, "col1")
	c.Check(node.target[1].name, Equals, "col2")
	c.Check(node.from[0].name, Equals, "tab1")
}
