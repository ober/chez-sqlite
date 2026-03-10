CC = gcc
CFLAGS = -shared -fPIC -O2
LIBS = -lsqlite3
SCHEME = scheme

.PHONY: all clean test

all: chez_sqlite_shim.so

chez_sqlite_shim.so: chez_sqlite_shim.c
	$(CC) $(CFLAGS) -o $@ $< $(LIBS)

test: chez_sqlite_shim.so
	LD_LIBRARY_PATH=. $(SCHEME) --libdirs src --script tests/sqlite-test.ss

clean:
	rm -f chez_sqlite_shim.so
