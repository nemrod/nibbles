all: nibbles

nibbles: start.s nibbles.s
	gcc $^ -o $@ -lcurses -lc -nostdlib

clean:
	rm -rf nibbles
