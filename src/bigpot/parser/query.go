package parser

import "errors"

//import "bigpot/relation"
import "bigpot/access"
import "bigpot/system"

type CommandType int
const (
	CMD_SELECT = iota
	CMD_INSERT
	CMD_UPDATE
	CMD_DELETE
)

type RangeVar struct {
	SchemaName   system.Name
	RelationName system.Name
}

type Expr struct {
	ReturnType system.Oid
}

type Var struct {
	Expr
	VarNo uint16
	VarAttNo uint16
}

type TargetEntry struct {
	Expr *Expr
	ResNo uint16
	ResName uint16
	ResJunk bool
}

type RteType int
const (
	RTE_RELATION = iota
	RTE_SUBQUERY
	RTE_JOIN
	RTE_VALUES
	RTE_FUNCTION
	RTE_CTE
)

type RangeTblEntry struct {
	RteType	RteType
	/* for relation */
	relid system.Oid
}

type Query struct {
	CommandType CommandType
	TargetList []*TargetEntry
	RangeTables []*RangeTblEntry
}

type Parser interface {
	Parse(query_string string) *Query
}

type ParserImpl struct {
	query string
	namespace []*RangeTblEntry
}

type ParserError struct {
	msg string
	location int
}

func (e ParserError) Error() string {
	return e.msg
}

func parseError(msg string) error {
	/* TODO: get stack */
	return ParserError{msg: msg}
}

func (parser *ParserImpl) Parse(query_string string) *Query {
	lexer := newLexer(query_string)
	yyParse(lexer)
	query := &Query{}

	return query
}

func (parser *ParserImpl) transformStmt(node Node) (*Query, error) {
	switch node.(type) {
	default:
		return nil, parseError("unknown node type")
	case *SelectStmt:
		return parser.transformSelectStmt(node.(*SelectStmt))
	}
	panic("unreachable")
}

func (parser *ParserImpl) transformSelectStmt(stmt *SelectStmt) (query *Query, err error) {
	query = &Query{CommandType: CMD_SELECT}
	err = nil
	if err = parser.transformFromClause(stmt); err != nil {
		return
	}
	if query.TargetList, err =
		parser.transformTargetList(stmt.targetList); err != nil {
		return
	}

	return
}

func (parser *ParserImpl) transformFromClause(stmt *SelectStmt) error {
	for _, item := range stmt.fromList {
		switch item.(type) {
		default:
			return parseError("unknown node type")
		case *RangeVar:
			rv := item.(*RangeVar)
			rte := &RangeTblEntry{}
			/* TODO: implement relation_open_rv() */
			relation, err := rv.OpenRelation()
			if err != nil {
				return err
			}
			rte.relid = relation.RelId
			/* TODO: make Alias and add it to namespace, not Rte */
			parser.namespace = append(parser.namespace, rte)
		}
	}

	return nil
}

func (parser *ParserImpl) transformTargetList(targetList []*ResTarget) (tlist []*TargetEntry, err error) {
	for _, item := range targetList {
		var tle *TargetEntry
		tle, err = parser.transformTargetEntry(item)
		if err != nil {
			return
		}
		tlist = append(tlist, tle)
	}

	return
}

func (parser *ParserImpl) transformTargetEntry(restarget *ResTarget) (tle *TargetEntry, err error) {
	tle = &TargetEntry{}
	err = nil

	tle.Expr, err = parser.transformExpr(restarget.val)

	return
}

func (parser *ParserImpl) transformExpr(node Node) (expr *Expr, err error) {
	switch node.(type) {
	default:
		return nil, parseError("unknown node type")
	case *ColumnRef:
	/* TODO: Explore namespace and transform to Var */

	}

	panic("unreachable")
}

func (rv *RangeVar) OpenRelation() (rel *access.Relation, err error) {
	class_rel, err := access.HeapOpen(access.ClassRelId)
	if err != nil {
		return nil, err
	}
	defer class_rel.Close()
	scankeys := []access.ScanKey {
		{access.Anum_class_relname, system.Datum(rv.RelationName)},
	}
	scan, err := class_rel.BeginScan(scankeys)
	if err != nil {
		return nil, err
	}
	defer scan.EndScan()
	tuple, err := scan.Next()
	if err != nil {
		return nil, errors.New("relation not found")
	}
	relid := tuple.Get(int32(1)).(system.Oid)

	return access.HeapOpen(relid)
}
