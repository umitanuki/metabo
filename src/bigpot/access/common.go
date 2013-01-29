package access

import "bigpot/system"

type Attribute struct {
	AttName		system.Name
	AttType		system.Oid
}

type TupleDesc struct {
	Attrs []*Attribute
}

var ClassTupleDesc = &TupleDesc{
	[]*Attribute{
		{"oid", system.OidType},
		{"relname", system.NameType},
	},
}
var ClassRelId system.Oid = 1259
var Anum_class_oid int32 = 1
var Anum_class_relname int32 = 2

var AttributeTupleDesc = &TupleDesc{
	[]*Attribute{
		{"attrelid", system.OidType},
		{"attname", system.NameType},
		{"attnum", system.Int4Type},
		{"atttype", system.OidType},
	},
}
var AttributeRelId system.Oid = 1249
var Anum_attribute_attrelid int32 = 1
var Anum_attribute_attname int32 = 2
var Anum_attribute_attnum int32 = 3
var Anum_attribute_atttype int32 = 4

type Relation struct {
	RelId system.Oid
	RelDesc *TupleDesc
}

type HeapTuple struct {

}

type Datum interface{}
type ScanKey struct {
	AttNum int32
	Val Datum
}

type RelationScan struct {
	Relation *Relation
	Forward bool
	ScanKeys []ScanKey // non-pointer, as usually this is short life
}

func HeapOpen(relid system.Oid) (*Relation, error) {
	if relid == ClassRelId {
		relation := &Relation {
			RelId: relid,
			RelDesc: ClassTupleDesc,
		}
		return relation, nil
	} else if relid == AttributeRelId {
		relation := &Relation {
			RelId: relid,
			RelDesc: AttributeTupleDesc,
		}
		return relation, nil
	}

	relation := &Relation{RelId: relid}

	class_rel, err := HeapOpen(ClassRelId)
	if err != nil {
		return nil, err
	}
	defer class_rel.Close()
	var scan_keys []ScanKey
	scan_keys = []ScanKey{
		{Anum_class_oid, Datum(relid)},
	}

	class_scan := class_rel.BeginScan(scan_keys)
	class_tuple := class_scan.Next()
	_ = class_tuple
//	relation = &Relation{
//		RelId: relid,
//	}

	attr_rel, err := HeapOpen(AttributeRelId)
	if err != nil {
		return nil, err
	}
	defer attr_rel.Close()
	scan_keys = []ScanKey{
		{Anum_attribute_attrelid, Datum(relid)},
	}

	attr_scan := attr_rel.BeginScan(scan_keys)
	var attributes []*Attribute
	for attr_tuple := attr_scan.Next();
		attr_tuple != nil;
		attr_tuple = attr_scan.Next() {
		attribute := &Attribute{
			AttName: attr_tuple.Get(Anum_attribute_attname).(system.Name),
			AttType: attr_tuple.Get(Anum_attribute_atttype).(system.Oid),
		}
		attributes = append(attributes, attribute)
	}
	relation.RelDesc = &TupleDesc{
		Attrs: attributes,
	}

	return relation, nil
}

func (relation *Relation) Close() {

}

func (relation *Relation) BeginScan(keys []ScanKey) *RelationScan{
	scan := &RelationScan{
		Relation: relation,
		Forward: true,
		ScanKeys: keys,
	}

	return scan
}

func (scan *RelationScan) Next() *HeapTuple {
//	htuple := &HeapTuple{}

	return nil
}

func (htuple *HeapTuple) Get(attnum int32) Datum {
	return nil
}
