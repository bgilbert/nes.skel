PROJ = skel

SOURCES = \
	chr/chr.asm \
	src/main.asm \
	src/nes.asm \
	src/nmi-cmd.asm \
	src/nmi-impl.asm

.PHONY: all
all: $(PROJ).nes

$(PROJ).nes $(PROJ).lst: $(SOURCES)
	64tass --flat --quiet -o "$@" -L "$(@:.nes=.lst)" src/main.asm

chr/chr.asm: chr/makechr
	$< > $@

chr/makechr: chr/makechr.c chr/font.h

.PHONY: clean
clean:
	@rm -f $(PROJ).nes $(PROJ).lst chr/chr.asm chr/makechr
