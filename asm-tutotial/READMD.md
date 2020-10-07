# 汇编基本学习教程

## 函数

函数是汇编中的精髓，是理解编程语言运作的重中之重。

### 栈

`栈` 是内存中非常重要的一部分，栈上分配的内存是可以通过`出栈`来自动回收的，是很多编程语言实现内存回收的关键。

在`x86`架构下，栈是从`高地址`向`低地址`伸展的，如下：

```
|        |   <- 栈顶，内存高地址
|        |
|        |
|        |
|        |
|        |
|        |   <- 栈底，内存低地址
```

每当一个元素`入栈`时，栈顶的地址就会向下递减一个单位(offset)，每当`出栈`时
栈顶的地址就会递增一个单位。

入栈：
```
|   a    |
|        |   <- 栈顶，内存高地址
|        |
|        |
|        |
|        |
|        |   <- 栈底，内存低地址
```

出栈：
```
    a        <- 元素 a 被拿出来了
|        |   <- 栈顶，内存高地址
|        |
|        |
|        |
|        |
|        |
|        |   <- 栈底，内存低地址
```

### 寄存器

与`栈`有关的寄存器主要有`3`个，分别是：
- eip：ip 寄存器，存放下一条指令的地址，eip 指到那，程序就得执行到那。
- esp：esp寄存器，存放`栈顶`地址。
- ebp：ebp寄存器，存放`栈底`地址。

当`esp`和`ebp`的地址相同时，则表示栈内存被用完了。


### 调试

我们来调试一个简单的汇编函数：

```asm
global main

eax_plus_1s:
    add eax, 1
    ret

main:
    mov eax, 0
    call eax_plus_1s
    ret
```

这段汇编代码非常简单，在`main`函数中将 `eax` 寄存器设置为0，然后调用`eax_plus_1s`
函数将`eax`中的值加1，随后返回。

首先，我们将这段汇编代码保存为`func.asm`，然后通过如下命令来运行调式：

```sh
nasm -f elf -g -F stabs func.asm -o func.o
gcc -m32 -g func.o -o func.a
gdb ./func.a
```

在 gdb 窗口中，首先我们先反汇编出`main`函数的汇编代码：

```sh
(gdb) disassemble main
Dump of assembler code for function main:
   0x000011a4 <+0>:	mov    $0x0,%eax
   0x000011a9 <+5>:	call   0x11a0 <eax_plus_1s>
   0x000011ae <+10>:	ret    
   0x000011af <+11>:	nop
End of assembler dump.
```

在此处我们需要在`call`这个指令打上一个断点，即：

```sh
b *0x000011a9
```

但是打上断点后，会报出如下错误：

```sh
(gdb) run
Starting program: /home/pedro/桌面/6.828/lab/asm-tutotial/func.a 
Warning:
Cannot insert breakpoint 1.
Cannot access memory at address 0x11a9
```

我们无法访问该地址上的内存！

注意：这是个很严重的`gdb`调试 bug，谷歌了半天也没有找到解决的办法。

所以，只能选择规避这个问题，如下：

首先，我们先删除这个断点1：

```sh
(gdb) delete breakpoints 1
```

然后，我们直接运行这个程序：

```sh
(gdb) run
```

接着，我们再次反汇编这个`main`函数：

```sh
(gdb) disassemble main
Dump of assembler code for function main:
   0x565561a4 <+0>:	mov    $0x0,%eax
   0x565561a9 <+5>:	call   0x565561a0 <eax_plus_1s>
   0x565561ae <+10>:	ret    
   0x565561af <+11>:	nop
End of assembler dump.
```

发现此时`call`指令的地址已经发生了变化，而这个地址是可以访问的！

> 此处可能是 gdb 运行时，地址未能及时映射的 bug。

再次打上断点：

```sh
b *0x565561a9
```

运行程序：

```sh
(gdb) run
Starting program: /home/pedro/桌面/6.828/lab/asm-tutotial/func.a 

Breakpoint 2, 0x565561a9 in main ()
```

此时断点已经成功触发，如下：

```sh
(gdb) disassemble main
Dump of assembler code for function main:
   0x565561a4 <+0>:	mov    $0x0,%eax
=> 0x565561a9 <+5>:	call   0x565561a0 <eax_plus_1s>
   0x565561ae <+10>:	ret    
   0x565561af <+11>:	nop
End of assembler dump.
```

这时，我们来查看`eip`寄存器的值：

```sh
(gdb) info register eip
eip            0x565561a9          0x565561a9 <main+5>
```

`eip` 存储的是下一条指令的地址，即`0x565561a9`，也就是`call`指令的地址。

我们再查看以下`esp`和`ebp`分别指向的栈顶和栈顶地址：

```sh
(gdb) info register esp
esp            0xffffd01c          0xffffd01c
(gdb) info register ebp
ebp            0x0                 0x0
```

和上述一致，esp 是高位内存地址，ebp 是低位内存地址。

接下来，我们使用`stepi`单步调试看看函数调用后的情况：

```sh
(gdb) stepi
0x565561a0 in eax_plus_1s ()
```

此时程序已经运行到了 `eax_plus_1s` 函数处。

看一看该函数的汇编代码：

```sh
(gdb) disassemble eax_plus_1s 
Dump of assembler code for function eax_plus_1s:
=> 0x565561a0 <+0>:	add    $0x1,%eax
   0x565561a3 <+3>:	ret    
End of assembler dump.
```

可以发现，函数名称及函数信息在内存里面是没有保存的，映射到内存后
全部变成了地址和指令。

此时函数调用已经发生，那么`eip`和`esp`的值会发生改变：

```sh
(gdb) info register eip
eip            0x565561a0          0x565561a0 <eax_plus_1s>
(gdb) info register esp
esp            0xffffd018          0xffffd018
```

eip 指向了下一个指令的地址，而 esp 的值从`0xffffd01c`变成了`0xffffd018`，
刚好减去了`4`，即 32 位。

再看一看 esp 中地址所指向的内存：

```sh
(gdb) p/x *(unsigned int*)$esp
$1 = 0x565561ae
```

它所指向的仍是个内存地址，且这个内存地址正好是`0x565561ae <+10>:	ret `指令的
地址。


也就是说，eax_plus_1s 函数执行完毕后，下一条指令地址已经被压入了栈中，待
eax_plus_1s 函数执行完毕，调用 ret 后，该指令地址又会被推入 eip。

然后返回 main 函数执行接下来的指令。

## 说明

`nmb.asm` 使用 `nasm` 作为汇编编译器，该文件演示了汇编如何使用寄存器
存储数据，如何将这些数据相加并退出的。

`func.asm` 一个简单的函数调用汇编程序，学习函数栈是如何工作的。


## 参考

- 汇编函数调用，https://zhuanlan.zhihu.com/p/24129384。