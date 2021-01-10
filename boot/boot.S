#include <inc/mmu.h>

# Start the CPU: switch to 32-bit protected mode, jump into C.
# The BIOS loads this code from the first sector of the hard disk into
# memory at physical address 0x7c00 and starts executing in real mode
# with %cs=0 %ip=7c00.

.set PROT_MODE_CSEG, 0x8         # kernel code segment selector  代码段选择子
.set PROT_MODE_DSEG, 0x10        # kernel data segment selector 数据段选择子
.set CR0_PE_ON,      0x1         # protected mode enable flag 保护模式 flag

.globl start
start:
  .code16                     # Assemble for 16-bit mode 告诉编译器，这里是 16 位模式
  cli                         # Disable interrupts 禁止中断；这条指令的地址是 0x7c00，即 bootloader 的起始地址
  cld                         # String operations increment

  # Set up the important data segment registers (DS, ES, SS).
  xorw    %ax,%ax             # Segment number zero ax 清零
  movw    %ax,%ds             # -> Data Segment 数据段清零
  movw    %ax,%es             # -> Extra Segment 额外段清零
  movw    %ax,%ss             # -> Stack Segment 栈段清零

  # Enable A20: 开始第 20 根线，为了兼容早期的PCs，所以默认是不开启的
  #   For backwards compatibility with the earliest PCs, physical
  #   address line 20 is tied low, so that addresses higher than
  #   1MB wrap around to zero by default.  This code undoes this.
seta20.1:
  inb     $0x64,%al               # Wait for not busy
  testb   $0x2,%al
  jnz     seta20.1                # 不一致就接着等

  movb    $0xd1,%al               # 0xd1 -> port 0x64  发送到端口
  outb    %al,$0x64

seta20.2:
  inb     $0x64,%al               # Wait for not busy
  testb   $0x2,%al
  jnz     seta20.2

  movb    $0xdf,%al               # 0xdf -> port 0x60
  outb    %al,$0x60

  # Switch from real to protected mode, using a bootstrap GDT
  # and segment translation that makes virtual addresses 
  # identical to their physical addresses, so that the 
  # effective memory map does not change during the switch.
  # 从实模式到保护模式，注意 cr0 不能使用立即数修改，要使用寄存器间接修改
  lgdt    gdtdesc
  movl    %cr0, %eax
  orl     $CR0_PE_ON, %eax
  movl    %eax, %cr0
  
  # Jump to next instruction, but in 32-bit code segment.
  # Switches processor into 32-bit mode.
  # 从 16 位实模式跳到 32 位保护模式
  ljmp    $PROT_MODE_CSEG, $protcseg

  .code32                     # Assemble for 32-bit mode  下面的是 32 位汇编
protcseg:
  # Set up the protected-mode data segment registers
  movw    $PROT_MODE_DSEG, %ax    # Our data segment selector 重新设置段选择子
  movw    %ax, %ds                # -> DS: Data Segment
  movw    %ax, %es                # -> ES: Extra Segment
  movw    %ax, %fs                # -> FS
  movw    %ax, %gs                # -> GS
  movw    %ax, %ss                # -> SS: Stack Segment
  
  # Set up the stack pointer and call into C.  将 start 函数的地址赋给栈顶，start 是 caller 的函数地址
  movl    $start, %esp
  call bootmain # 调用 main 函数

  # If bootmain returns (it shouldn't), loop.
spin:
  jmp spin  # 循环

# Bootstrap GDT
.p2align 2                                # force 4 byte alignment  4 字节对齐
gdt:
  SEG_NULL				# null seg
  SEG(STA_X|STA_R, 0x0, 0xffffffff)	# code seg
  SEG(STA_W, 0x0, 0xffffffff)	        # data seg

gdtdesc:
  .word   0x17                            # sizeof(gdt) - 1
  .long   gdt                             # address gdt

