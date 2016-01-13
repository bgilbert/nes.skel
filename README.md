# Hello World for the NES

This is a simple skeleton project for the Nintendo Entertainment System.

## Architecture

The NMI handler is responsible for updating PPU memory (during the vertical
blanking interval) by executing commands placed into a command buffer by the
main thread of execution.  The NMI handler will not execute any commands
unless the main thread is blocking in `run_nmi`.

All other tasks should be performed in the main thread: game logic, input
processing, etc.

To queue a command for the NMI handler: `ldy cmd_off`, store bytes into the
queue using `.ccmd` and/or `.cmd`, then `sty cmd_off`.  Then, to wait for
the next frame and execute pending commands, `jsr run_nmi`.

## Build requirements

- [64tass](http://tass64.sourceforge.net/)
- C compiler
- Make

## Building

```
make
```

## Notes

- The code addresses in the first column of the .lst file are $7ff0 bytes
  too low.

- 64tass emits `warning: memory bank exceeded` at build time.  This warning
  is harmless and there doesn't seem to be a way to avoid it.

## Useful links

- [6502 instruction set reference](http://e-tradition.net/bytes/6502/6502_instruction_set.html)
- [Good description of 6502 addressing modes](https://en.wikibooks.org/wiki/6502_Assembly)
- [64tass manual](http://tass64.sourceforge.net/)
- [Nesdev wiki](http://wiki.nesdev.com/w/index.php/Nesdev_Wiki)
