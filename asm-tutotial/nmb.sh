nasm -f elf nmb.asm -o nmb.o
gcc -m32 nmb.o -o nmb.a
./nmb.a ; echo $?