# lab1

## Exercises

### Exercise 3

在`b *0x7c00`地址处打上断点，使用`c`运行程序至断点处，使用`x/i`查看下一条被执行的指令：

```sh
(gdb) b *0x7c00
Breakpoint 1 at 0x7c00
(gdb) c
Continuing.
[   0:7c00] => 0x7c00:  cli

Breakpoint 1, 0x00007c00 in ?? ()
(gdb) x/i
   0x7c01:      cld
(gdb) x/i
   0x7c02:      xor    %ax,%ax
(gdb)
```

`0x7c00` 是 bootloader 的开始地址，这个地址由 `BIOS` 完成自检后跳转，然后开始执行 bootloader
`cli` 对应 bootloader 的下一条指令，而`cld`是下一条指令。

在 `boot/boot.S` 和 `obj/boot/boot.asm` 中的指令 `xorw %ax,%ax` 会被编译成如下指令：

```s
xor  %ax,%ax
```

`xor` 是异或指令，会清零 `%ax` 寄存器。

Be able to answer the following questions:

- At what point does the processor start executing 32-bit code? What exactly causes the switch from 16- to 32-bit mode?

```s
  ljmp    $PROT_MODE_CSEG, $protcseg

  .code32                     # Assemble for 32-bit mode  下面的是 32 位汇编
protcseg:
  # Set up the protected-mode data segment registers
  movw    $PROT_MODE_DSEG, %ax    # Our data segment selector 重新设置段选择子
```

代码不会说谎，在 `ljmp` 这里跳转到保护模式下，之前一直在做保护模式的准备工作，如打开第 20 根总线，然后后面的代码以`32`位进行编译，开始
在保护模式下执行。

```sh
(gdb) si
[   0:7c2d] => 0x7c2d:  ljmp   $0x8,$0x7c32
```

在 `gdb` 的调试下，可以清楚看到在 `0x7c2d` 地址处进行跳转，目标地址是`0x7c32`，跳转后进入 `32` 位保护模式。

- What is the last instruction of the boot loader executed, and what is the first instruction of the kernel it just loaded?

此处设置`esp`栈顶地址，然后调用`0x7d25`地址处的`bootmain函数`。

```sh
(gdb) si
=> 0x7c40:      mov    $0x7c00,%esp
0x00007c40 in ?? ()
(gdb) si
=> 0x7c45:      call   0x7d25
```

调用 `bootmain` 函数后，程序开始执行下面代码：

```sh
00007d25 <bootmain>:
{
    7d25:	f3 0f 1e fb          	endbr32
    7d29:	55                   	push   %ebp
    7d2a:	89 e5                	mov    %esp,%ebp
    7d2c:	56                   	push   %esi
    7d2d:	53                   	push   %ebx
	readseg((uint32_t)ELFHDR, SECTSIZE * 8, 0);
    7d2e:	52                   	push   %edx
    7d2f:	6a 00                	push   $0x0
    7d31:	68 00 10 00 00       	push   $0x1000
    7d36:	68 00 00 01 00       	push   $0x10000
    7d3b:	e8 a2 ff ff ff       	call   7ce2 <readseg>
	if (ELFHDR->e_magic != ELF_MAGIC) // 读取失败，直接 bad
    7d40:	83 c4 10             	add    $0x10,%esp
    7d43:	81 3d 00 00 01 00 7f 	cmpl   $0x464c457f,0x10000
    7d4a:	45 4c 46
    7d4d:	75 38                	jne    7d87 <bootmain+0x62>
	ph = (struct Proghdr *)((uint8_t *)ELFHDR + ELFHDR->e_phoff);
    7d4f:	a1 1c 00 01 00       	mov    0x1001c,%eax
	eph = ph + ELFHDR->e_phnum;
    7d54:	0f b7 35 2c 00 01 00 	movzwl 0x1002c,%esi
	ph = (struct Proghdr *)((uint8_t *)ELFHDR + ELFHDR->e_phoff);
    7d5b:	8d 98 00 00 01 00    	lea    0x10000(%eax),%ebx
	eph = ph + ELFHDR->e_phnum;
    7d61:	c1 e6 05             	shl    $0x5,%esi
    7d64:	01 de                	add    %ebx,%esi
	for (; ph < eph; ph++)
    7d66:	39 f3                	cmp    %esi,%ebx
    7d68:	73 17                	jae    7d81 <bootmain+0x5c>
		readseg(ph->p_pa, ph->p_memsz, ph->p_offset);
    7d6a:	50                   	push   %eax
	for (; ph < eph; ph++)
    7d6b:	83 c3 20             	add    $0x20,%ebx
		readseg(ph->p_pa, ph->p_memsz, ph->p_offset);
    7d6e:	ff 73 e4             	pushl  -0x1c(%ebx)
    7d71:	ff 73 f4             	pushl  -0xc(%ebx)
    7d74:	ff 73 ec             	pushl  -0x14(%ebx)
    7d77:	e8 66 ff ff ff       	call   7ce2 <readseg>
	for (; ph < eph; ph++)
    7d7c:	83 c4 10             	add    $0x10,%esp
    7d7f:	eb e5                	jmp    7d66 <bootmain+0x41>
	((void (*)(void))(ELFHDR->e_entry))(); // 调用函数了！！！这里会从软盘中读取代码，然后在内存中执行这段代码
    7d81:	ff 15 18 00 01 00    	call   *0x10018
}
```

bootloader 的最后一条执行代码是：

```c
	// call the entry point from the ELF header
	// note: does not return!
	((void (*)(void))(ELFHDR->e_entry))(); // 调用函数了！！！这里会从软盘中读取代码，然后在内存中执行这段代码，调用的是内核的开始函数
```

因此进入内核的执行其实就是：

```s
call *0x10018
```

即 `0x10018` 处正是内核的入口地址。我们打上一个断点`b *0x10018`。

```sh
(gdb) b *0x10018
Breakpoint 2 at 0x10018
(gdb)
```

- Where is the first instruction of the kernel?

内核的第一条指令，在 `obj/kernel/kernel.asm` 中：

```s
entry:
	movw	$0x1234,0x472			# warm boot
```

- How does the boot loader decide how many sectors it must read in order to fetch the entire kernel from disk? Where does it find this information?

bootloader 如何知道自己必须读取哪些 sectors，它是从哪得到这些信息的？

在 `bootmain` 中已经给出了答案：

```c
	// read 1st page off disk
	readseg((uint32_t)ELFHDR, SECTSIZE * 8, 0);

	// is this a valid ELF?
	if (ELFHDR->e_magic != ELF_MAGIC) // 读取失败，直接 bad
		goto bad;

	// load each program segment (ignores ph flags)
	// ph 是 program segment header
	ph = (struct Proghdr *)((uint8_t *)ELFHDR + ELFHDR->e_phoff); // segment 偏移
	eph = ph + ELFHDR->e_phnum;																		// segment 数量
	for (; ph < eph; ph++)
		// p_pa is the load address of this segment (as well
		// as the physical address)
		readseg(ph->p_pa, ph->p_memsz, ph->p_offset); // 读取每一个 segment
```

首先读取第一个`segment`，在这个 segment 的头部中拿到 `e_phnum`，即 segment 的数量，然后依次读取。

### Exercise 4

阅读 The C Programming Language，然后理解 C 语言中的指针，指针太重要了~~~
指针练习参考[pointers](https://pdos.csail.mit.edu/6.828/2018/labs/lab1/pointers.c)。

### Exercise 5

介绍了 bootloader 的起始地址`0x7c00`，尝试改变`boot/Makefrag`中的链接地址，运行程序看会出现什么错误。

You should now be able to understand the minimal ELF loader in boot/main.c. It reads each section of the kernel from disk into memory at the section's load address and then jumps to the kernel's entry point.

所以`boot/main.c` 做了什么呢？它从磁盘读取了内核文件的每一个 section 到内存的加载地址，每一个 section 都有自己的加载地址，然后程序跳转到内核
的入口地址。

### Exercise 6

通过 GD B 的 `x` 指令，我们可以通过地址查看内存内容，如 `x/Nx ADDR`，会打印 ADDR 处的 N 个 words 内存数据，注意在 GNU 中一个 word 是两个字节。

观察 `0x00100000` 地址处的 8 个字长内存，`x/8x 0x00100000`，在 BIOS 进入 bootloader，bootloader 进入 kernel 的时候，它们的值有何不同？为什么？

程序刚开始，全是 0：

```sh
(gdb) x/8x 0x00100000
0x100000:       0x00000000      0x00000000      0x00000000      0x00000000
0x100010:       0x00000000      0x00000000      0x00000000      0x00000000
```

进入 `bootloader`，全是 0：

```sh
(gdb) x/8x 0x00100000
0x100000:       0x00000000      0x00000000      0x00000000      0x00000000
0x100010:       0x00000000      0x00000000      0x00000000      0x00000000
```

进入`kernel`之前，即`call *0x10018`：

```sh
(gdb) x/8x 0x00100000
0x100000:       0x1badb002      0x00000000      0xe4524ffe      0x7205c766
0x100010:       0x34000004      0x2000b812      0x220f0011      0xc0200fd8
```

此处的`0x100000`正是内核的起始代码段，在读入 elf 文件后会将代码加载到此处内存，即：

```s
entry:
	movw	$0x1234,0x472			# warm boot
f0100000:	02 b0 ad 1b 00 00    	add    0x1bad(%eax),%dh
```

因此前后的内存不同，是因为读入了 ELF 内核。

### Exercise 7

virtual address 0xf0100000 (the link address at which the kernel code expects to run) to physical address 0x00100000 (where the boot loader loaded the kernel into physical memory).

ld 会将 elf 中的链接虚拟地址加载到物理地址 `0x00100000` 处，即上面的猜测是正确的，0x00100000 处确实是内核代码。

虚拟地址的开始在`0xF0100000`处，这是由 `kernel.ld` 脚本来定义的。

为什么需要虚拟地址，因为进入保护模式后，CPU 访问的地址不再是物理地址，而是线性地址。

在 `movl %eax, %cr0` 指令，开启分页之前和之后，运行之前查看 `0x00100000` 和 `0xf0100000`地址的内容。

之前：

```sh
(gdb) x/8x 0x00100000
0x100000:       0x1badb002      0x00000000      0xe4524ffe      0x7205c766
0x100010:       0x34000004      0x2000b812      0x220f0011      0xc0200fd8
(gdb) x/8x 0xf0100000
0xf0100000 <_start-268435468>:  0x00000000      0x00000000      0x00000000      0x00000000
0xf0100010 <entry+4>:   0x00000000      0x00000000      0x00000000      0x00000000
```

之后：

```sh
(gdb) x/8x 0x00100000
0x100000:       0x1badb002      0x00000000      0xe4524ffe      0x7205c766
0x100010:       0x34000004      0x2000b812      0x220f0011      0xc0200fd8
(gdb) x/8x 0xf0100000
0xf0100000 <_start-268435468>:  0x1badb002      0x00000000      0xe4524ffe      0x7205c766
0xf0100010 <entry+4>:   0x34000004      0x2000b812      0x220f0011      0xc0200fd8
```

可以看到虚拟地址`0xf0100010`映射到了物理地址`0x00100000`处。

### Exercise 8

实现`printf`等系列函数，这些函数并不是直接就有的，而是需要操作系统来实现的。

完善`lib/printfmt.c#vprintfmt()` 函数，支持 `%o`，即 8 进制，抄袭一下 16 进制的实现就可以了。

1. `printf.c` 实现依赖 `console.c`。
2. 如果字符的坐标超过了 CRT_SIZE，将第一行清空，并上移下面的所有数据，然后空出最后一行。

### Exercise 9

关于 x86 中的栈，`esp` 指向栈顶，即栈的最高位，栈向低位推进。

### Exercise 10,11,12

完成`mon_backtrace`函数，打印函数调用栈的信息。

x86 函数调用遵循如下规则：

1. 执行 call 指令前，函数调用者将参数入栈，按照函数列表从右到左的顺序入栈
2. call 指令会自动将当前 eip 入栈，ret 指令将自动从栈中弹出该值到 eip 寄存器
3. 被调用函数负责：将 ebp 入栈，esp 的值赋给 ebp。

因此想要拿到`eip`，`esp` 和参数需要当前的读取栈底元素。即拿到`ebp`后，通过指针操作拿到`eip`和参数地址然后打印数据。

深坑！！！ `debuginfo_eip` 这个函数并没有实现完毕，所以`line`一直都是`0`，这个地方是需要使用函数来寻找的。

`debuginfo_eip` 会从 ELF 文件中的 symbols 即符号表中去寻找函数名称和行号，如下：

```c
int olline = lline, orline = rline;
stab_binsearch(stabs, &olline, &orline, N_SOL, (!(lline == lfile && rline == rfile)) * addr + info->eip_fn_addr);
// 如果没有找到 N_SOL
if (olline > orline)
{
    stab_binsearch(stabs, &lline, &rline, N_SLINE, addr);
    // 如果在 N_SLINE 也没有找到
    if (lline > rline)
    {
        return -1;
    }
}
```

通过二分查找 `stabs` 中的行号，当 `lline <= rline` 时查找成功，则赋值 `eip_line`。留个坑，这里没搞懂~

## ELF

An ELF binary starts with a fixed-length ELF header, followed by a variable-length program header listing each of the program sections to be loaded.

ELF 有一个固定长度的头部，然后是 section headers list，即 section header 的列表，数量是动态的。

通过 `objdump` 查看 ELF 文件的执行地址：

```sh
$ objdump -f obj/kern/kernel

obj/kern/kernel:     file format elf32-i386
architecture: i386, flags 0x00000112:
EXEC_P, HAS_SYMS, D_PAGED
start address 0x0010000c
```

## Hints

- jos 只能使用 `256m` 内存。
- 先搞清楚 `ELF` 文件格式！！！

## 参考资料

- lab1：https://pdos.csail.mit.edu/6.828/2018/labs/lab1/
- 详细： https://www.cnblogs.com/gatsby123/p/9759153.html
- 更加详细：https://jiyou.github.io/blog/2018/04/15/mit.6.828/jos-lab1/
