package access

import (
	. "launchpad.net/gocheck"
	"testing"
)

func Test(t *testing.T) {
	TestingT(t)
}

type AccessSuite struct{}
var _ = Suite(&AccessSuite{})

func (s *AccessSuite) TestHeapOpen_class(c *C) {
	relation, err := HeapOpen(ClassRelId)
	if err != nil {
		c.Error("HeapOpen failed")
	}
	c.Check(relation.RelId, Equals, ClassRelId)
	c.Check(len(relation.RelDesc.Attrs), Equals, 2)
}

func (s *AccessSuite) TestHeapOpen_attribute(c *C) {
	relation, err := HeapOpen(AttributeRelId)
	if err != nil {
		c.Error("HeapOpen failed")
	}
	c.Check(relation.RelId, Equals, AttributeRelId)
	c.Check(len(relation.RelDesc.Attrs), Equals, 4)
}
