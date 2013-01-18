
all: scan.go gram.go
	go build bigpot/parser

scan.go: scan.l
	golex -t $^ | gofmt > $@

gram.go: gram.y
	go tool yacc -o $@ $^

test: scan.go gram.go
	go test bigpot/parser

clean:
	rm -f scan.go gram.go
