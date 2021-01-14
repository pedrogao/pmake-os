# lab3

本节主要介绍用户态的实现，包括用户态程序执行，异常处理和系统调用。

## 读代码

在做实验之前一定要读代码，不然完全不知道自己要干什么，本节涉及的代码很多，首先是`inc`下的新文件：

- env.h：环境相关代码，即程序运行环境。
- trap.h：trap 陷入内核相关代码，陷入内核需要保护的上下文
- syscall.h：系统调用相关
- lib.h：库文件代码，系统调用函数实现等

然后是`kern`下的新文件：

- env.h：环境相关，环境列表，当前环境，段选择子，以及创建、销毁环境的函数定义。
- env.c：环境实现
- trap.h：内核中 trap 的定义
- trap.c：trap 的实现
- trapentry.S：trap 的入口，trap 会将标记序号推入寄存器中，因此需要汇编来实现
- syscall.h：系统调用函数声明
- syscall.c：系统调用实现

`lib` 下的新文件：

- entry.S：用户态的入口
- libmain.c：用户态程序执行 main 函数
- syscall.c：用户态系统调用
- console.S：用户态 IO 函数
- exit.c：用户态程序退出
- panic.c：用户态程序 panic

`user`下的新文件：

```sh
├── Makefrag makefile fragment
├── badsegment.c bad segment
├── breakpoint.c 断点
├── buggyhello.c hello
├── buggyhello2.c hello2
├── divzero.c 除0
├── evilhello.c evil hello
├── faultread.c 错误读取
├── faultreadkernel.c 错误读内核
├── faultwrite.c 错误写
├── faultwritekernel.c 错误写内核
├── hello.c hello
├── sendpage.c send page
├── softint.c 软整型
├── testbss.c test bss
└── user.ld 用户态链接文件
```

然后本节会使用 inline assembly，参考：https://www.ibm.com/developerworks/linux/library/l-ia/index.html。

## PartA：用户环境和异常处理


