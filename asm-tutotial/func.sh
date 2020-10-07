nasm -f elf -g -F stabs func.asm -o func.o
gcc -m32 -g func.o -o func.a
gdb ./func.a