package parser

import (
	. "launchpad.net/gocheck"
//	"testing"
	"bigpot/access"
	"bigpot/system"
)

var _ = Suite(&MySuite{})
func (s *MySuite) TestBuildAlias(c *C) {
	relation := access.Relation{
		RelName: "mytable",
		RelDesc: &access.TupleDesc{
			Attrs: []*access.Attribute{
				{"mycol1", system.NameType},
				{"mycol2", system.Int4Type},
			},
		},
	}

	alias := buildAlias(&relation)
	c.Check(alias.AliasName, Equals, "mytable")
	c.Check(len(alias.ColumnNames), Equals, 2)
	c.Check(alias.ColumnNames[0], Equals, "mycol1")
	c.Check(alias.ColumnNames[1], Equals, "mycol2")
}
