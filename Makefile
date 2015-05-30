duped: duped.d
	dmd $< -release -inline -of$@

install: duped
	install -D $< /usr/local/bin
.PHONY: install

clean:
	rm -f duped duped.o
.PHONY: clean
