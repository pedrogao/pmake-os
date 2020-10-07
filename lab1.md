# lab1

## Part1: BIOS

两个命令窗口，一个使用：

``` sh
make qemu-nox-gdb 
```

另一个使用：

``` sh
make gdb
```

在 gdb 窗口中输出如下信息：

``` sh
[f000:fff0]    0xffff0:	ljmp   $0x3630,$0xf000e05b
```

* BIOS 大小为 64k，物理地址范围是 `[f000:fff0]` 。
* PC 开机时执行 `ljmp` 指令，设置 `pc` 寄存器的值，0xffff0 是 BIOS 尾部地址，此处会跳到 BIOS 前半部分，并执行一些初始化工作。

单步调试：

``` sh
(gdb) si
[f000:e05b]    0xfe05b:	cmpw   $0xffb8,%cs:(%esi) # 比较大小，改变PSW
0x0000e05b in ?? ()
(gdb) si
[f000:e062]    0xfe062:	jne    0xd241d124 # 不相等则跳转
0x0000e062 in ?? ()
(gdb) si
[f000:e066]    0xfe066:	xor    %edx,%edx # 清零 edx
0x0000e066 in ?? ()
(gdb) si
[f000:e068]    0xfe068:	mov    %edx,%ss
0x0000e068 in ?? ()
(gdb) si
[f000:e06a]    0xfe06a:	mov    $0x7000,%sp # 最关键
(gdb) si
[f000:e070]    0xfe070:	mov    $0x132e,%dx
0x0000e070 in ?? ()
(gdb) si
[f000:e076]    0xfe076:	jmp    0x5576cf9e
```

这几步都是 BIOS 操作，最后一条指令，BIOS将控制权给到了 `0x5576cf9e` 处的 boot loader。即 `boot/boot.S` 的汇编程序文件，后面执行的代码均是该文件中的代码。

总结一下：

> The BIOS loads this code from the first sector of the hard disk into
> memory at physical address 0x7c00 and starts executing in real mode
> with %cs=0 %ip=7c00.

BIOS 会将磁盘的第一个扇区的 512 字节加载到 0x7c00 处，然后将 cs 和 ip 寄存器
分别设置为 0x0000 和 0x7c00，并以实模式的方式运行。

## Part2:boot loader

此时，cpu 仍在实模式下工作。

BIOS 将 CPU 执行权转交给了 boot loader，即 `boot/boot.S` 和 `boot/main.c` 文件。注意 BIOS 会先加载 `boot.S` 文件，在 `boot.S` 文件的最后会通过 `call` 指令来调用 `main.c` 。详见 boot. S 文件。

boot loader 会做如下两件事情：

1. 从实模式进入保护模式，并加载全部描述符表（boot/boot.S）。
2. 从磁盘加载 kernel 到内存（boot/main.c）。

汇编不怎么熟，因此挑几个重要的说一下：

``` s
cli                         # Disable interrupts
#
#...
seta20.1:
#
#...
  lgdt    gdtdesc
  movl    %cr0, %eax
  orl     $CR0_PE_ON, %eax
  movl    %eax, %cr0
#
#...
  movl    $start, %esp
  call bootmain
```

`cli` 指令是 boot loader的第一条指令，会禁止中断响应。
`seta20.1` 会开启 A20，即处理器的第21根地址线，序号从 0 开始，
所以 21 是 A20。
`movl    %eax, %cr0` 会将 cr0 寄存器的第一位置设为1，即开启保护模式。

注意，cr0 中包含了6个预定义标志，0位是保护允许位PE(Protedted Enable)，用于启动保护模式，如果PE位置1，则保护模式启动，如果PE=0，则在实模式下运行。

即这段汇编代码会将实模式变为保护模式。

然后 `call bootmain` 会调用 `main.c` 中的 c 语言代码。

设置 `0x7c00` 断点，观察从 BIOS 到 boot loader 的过程。

``` 
(gdb) b *0x7c00
Breakpoint 1 at 0x7c00
(gdb) c
Continuing.
[   0:7c00] => 0x7c00:	cli    
```

此时 BIOS 会从文件中加载 loader，如下:

``` 
Booting from Hard Disk.
```

`boot.S` 和 `main.c` 会被处理成一个文件，文件大小固定为 512 字节，并且以 0x55AA 结尾，且会被加载到第一个扇区。

而第二个扇区用来加载内核文件，且必须为 ELF 文件格式， `main.c` 代码的作用就是将内核以 elf 格式来读取，并且校验，待读取完毕后，通过 elf 头文件的入口来进入内核：

``` c
((void (*)(void))(ELFHDR->e_entry))();
```

至此，boot loader 已经完成了它的使命，CPU 正式交给了操作系统来控制。

## Part3: The kernel

进入到内核后，内核接管 CPU 控制权，并开始做第一件非常重要的事情，将虚拟地址与物理地址映射，以后开始访问虚拟地址。

在 JOS 中，目前通过 `kern/entrypgdir.c` 文件映射了[0, 4MB)地址，代码如下：

``` s
	# Load the physical address of entry_pgdir into cr3.  entry_pgdir
	# is defined in entrypgdir.c.
	movl	$(RELOC(entry_pgdir)), %eax
	movl	%eax, %cr3
	# Turn on paging.
	movl	%cr0, %eax
	orl	$(CR0_PE|CR0_PG|CR0_WP), %eax
	movl	%eax, %cr0
```

将地址目录表信息加载到 eax 寄存器中，并将目录表信息存储到 cr3 寄存器中，然后打开 cr0 中的分页标志位，正式开启了分页功能，即虚拟内存映射到物理内存。

> 注意：此处可通过 gdb 来观察内存映射前后的信息。

函数调用栈，在 `entry.S` 中会初始化一个栈，如下：

``` s
	movl	$0x0,%ebp			# nuke frame pointer

	# Set the stack pointer
	movl	$(bootstacktop),%esp

	# now to C code
	call	i386_init
```

首先将 ebp 栈底的值设置为 `0x0` ，然后将 esp 栈顶的值设置为 `bootstacktop` 。

函数调用通过 `call` 来实现，函数完毕后则调用 `ret` 来回到上一个函数处。每一个函数都有一个独立的栈，其实就是一段内存，通过 ebp 和 esp 来实现栈。

## 知识点

### 处理器的第一条指令

最早期的 16-bit 8088 处理器仅支持 1MB(0x00000000~0x000FFFFF)的物理寻址能力。
后面的 80286和80386 分别支持了 16MB 和 4GB的物理寻址能力。

为了向前兼容，所以保留了最初 1MB 的内存布局。PC 通电后，会将 `CS` 寄存器设置为 `0xf000` ， `IP` 寄存器设置为 `0xfff0` ，即第一条指令在物理内存 0xffff0处，该地址
位于BIOS区域的尾部。

### CS: IP 寄存器

这两个寄存器非常重要，CS全程 Code Segment，即代码段寄存器，对应于内存中的存放代码的内存区域，用来存放内存代码段区域的入口地址（段基址）。

CPU在执行指令时，通过代码寄存器CS和指令指针寄存器IP（instruction Pointer）来确定要执行的下一条指令的内存地址。

CS: IP 两个寄存器指示了CPU当前要执行的指令地址，计算方式一般为CS左移4位然后加上IP寄存器，作为地址去取内容。

``` sh
[f000:fff0]    0xffff0:	ljmp   $0x3630,$0xf000e05b
0x0000fff0 in ?? ()

* symbol-file obj/kern/kernel

warning: A handler for the OS ABI "GNU/Linux" is not built into this configuration
of GDB.  Attempting to continue with the default i8086 settings.

(gdb) si
[f000:e05b]    0xfe05b:	cmpw   $0xffb8,%cs:(%esi)
```

因此在 PC 通电后，CS 和 IP 寄存器会被赋默认值，即 `[f000:fff0]` 。

因此 `0xffff0` 地址处的指令将会作为第一条指令，该指令为：

``` sh
0xffff0:	ljmp   $0x3630,$0xf000e05b
```

该指令从 BIOS 尾部跳转到了前半部分，并设置了新的 IP 值，即 `[f000:e05b]` 。

### 控制台打印字符

打印函数会将字符输入到虚拟地址，如 `0xF00B8000` ，但该虚拟地址最终仍会指向物理地址 `0xB8000` 处，此处的物理地址其实就是显存的地址。

因此打印的本质还是向显存输出数据。

## 总结

这一个 lab，真的是吐一口老血啊，知识点真的是多，原来几乎不懂汇编，对 BIOS 和 boot loader 也知识大概知道一点，函数调用栈也是似懂非懂的。

这下子，把我捶的翻皮水。不过整个根下来，读文档，读代码，然后调试确实收获巨大。如下：

* 了解了 PC 启动的流程，从 `通电` -> `BIOS` -> `boot loader` -> `kernel` ，这一整个流程 debug 下来确实很爽。
* 对很多寄存器有了重大的认识，如 cr0 的实模式到保护模式的切换，cr3 的页表，与 cr0 结合一起实现物理内存到虚拟内存的映射。
* 虚拟内存的认识，函数调用栈的认识，原来一直只有一个初步的概念，但真正的调试才指导 esp，eip，ebp 的配合，也从本质上理解了函数，其实就是一段内存，每次调用只是跳转地址，但是需要保存之前的地址。
* 测试还未通过，同志仍需努力！

## 参考

* https://www.cnblogs.com/gatsby123/p/9759153.html。
* 过程：https://blog.dingbiao.top/2020/07/24/23.html。
* https://www.cnblogs.com/fatsheep9146/p/5115086.html。
