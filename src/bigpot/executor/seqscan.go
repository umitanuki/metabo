package executor

import "bigpot/access"
import "bigpot/planner"

type Node interface {
	Init()
	Exec() access.HeapTuple
	End()
}

type Scan interface {
	GetNext() access.HeapTuple
}

type SeqScan struct {
	planner.SeqScan
	relation *access.Relation
	scan *access.RelationScan
	executor Executor
}

func (scan *SeqScan) Init() {
	var err error
	scan.relation, err = access.HeapOpen(scan.RangeTable.RelId)
	if err != nil {
		/* TODO: do stuff */
	}
	emptykeys := []access.ScanKey{}
	scan.scan, err = scan.relation.BeginScan(emptykeys)
	if err != nil {
		/* TODO: do stuff */
	}
}

func (scan *SeqScan) Exec() access.HeapTuple {
	/* TODO: projection */
	return scan.GetNext()
}

func (scan *SeqScan) GetNext() access.HeapTuple {
	if tuple, err := scan.scan.Next(); err == nil {
		return tuple
	}

	return nil
}

func (scan *SeqScan) End() {
	scan.scan.EndScan()
	scan.relation.Close()
}
