package access

import (
	. "launchpad.net/gocheck"
	"testing"
	"fmt"
	"strconv"
	"bigpot/system"
)

func init() {
	DatabaseDir = "testdata"
}

func Test(t *testing.T) {
	TestingT(t)
}

type AccessSuite struct{}
var _ = Suite(&AccessSuite{})

func (s *AccessSuite) TestHeapOpen_class(c *C) {
	relation, err := HeapOpen(ClassRelId)
	if err != nil {
		c.Error(err)
	}
	c.Check(relation.RelId, Equals, ClassRelId)
	c.Check(len(relation.RelDesc.Attrs), Equals, 2)
}

func (s *AccessSuite) TestHeapOpen_attribute(c *C) {
	relation, err := HeapOpen(AttributeRelId)
	if err != nil {
		c.Error(err)
	}
	c.Check(relation.RelId, Equals, AttributeRelId)
	c.Check(len(relation.RelDesc.Attrs), Equals, 4)
}

func ExampleHeapScan_class() {
	relation, err := HeapOpen(ClassRelId)
	if err != nil {
		fmt.Printf("%s", err)
	}
	defer relation.Close()

	scan, err := relation.BeginScan(nil)
	if err != nil {
		fmt.Printf("%s", err)
		return
	}

	defer scan.EndScan()
	for i := 0; ; i++ {
		tuple, err := scan.Next()
		if err != nil {
			break
		}
		fmt.Printf("%d,%d:%s\n", i, 1, strconv.Itoa(int(tuple.Get(1).(system.Oid))))
		fmt.Printf("%d,%d:%s\n", i, 2, tuple.Get(2).(system.Name))
	}

	// OUTPUT:
	// 0,1:1259
	// 0,2:bp_class
	// 1,1:1249
	// 1,2:bp_attribute
}
