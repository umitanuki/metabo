
all: scan.go gram.go
	go build metabo/parser

scan.go: scan.l
	golex -t $^ | gofmt > $@

gram.go: gram.y
	go tool yacc -o $@ $^

test: scan.go gram.go
	go test metabo/parser

coverage: scan.go gram.go
	gocov test metabo/parser | gocov report

clean:
	rm -f scan.go gram.go y.output
