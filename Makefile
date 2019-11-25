# Makefile contributed by jtsiomb

src = doom.asm

.PHONY: all
all: doom.img

doom.img: $(src)
	nasm -f bin -l doom.lst -o $@ $(src)

.PHONY: clean
clean:
	$(RM) doom.img

.PHONY: runqemu
runqemu: doom.img
	qemu-system-i386 -fda doom.img
