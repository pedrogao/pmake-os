# lab2

## 介绍

这个实验的目的是操作系统的内存管理，即`memory management of OS`。

内存管理主要分为两个部分：

1. 内核中的物理内存分配。物理内存的分配单位是页（page），每一页的大小是`4096`字节，我们的任务是通过数据结构
   来记录哪些物理页被分配了，哪些被释放了，哪些是空闲的，并且哪些页是共享的，并管理这些物理页的分配和释放。
2. 虚拟内存的管理。虚拟内存通过 x86 架构中的 MMU 来直接映射，因此我们的任务是管理映射表，从而 CPU 可以直接将虚拟内存转换为物理内存。

着重关注 `memlayout.h` 、 `pmap.h` 和 `inc/mmu.h` 三个文件，上面有重要的定义。

- inc/mmu.h：MMU 相关，包括内存页、内存段的定义
- memlayout.h：x86 内存布局
- pmap.h：内存初始化操作

## Part1 物理页管理

需要实现一个物理页内存分配器，通过`struct PageInfo`结构体链表来对应一个物理页，在实现虚拟内存之前必须先实现物理内存的管理。

### Exercise1

实现`kern/pmap.c`文件中的函数：

- boot_alloc()
- mem_init() (only up to the call to check_page_free_list(1))
- page_init()
- page_alloc()
- page_free()

函数具体实现细节以及函数说明见代码。

## Part2 虚拟内存

在这个部分开始之前，熟悉一下 x86 保护模式下的分段和分页。

### 虚拟、线性和物理地址

```
           Selector  +--------------+         +-----------+
          ---------->|              |         |           |
                     | Segmentation |         |  Paging   |
Software             |              |-------->|           |---------->  RAM
            Offset   |  Mechanism   |         | Mechanism |
          ---------->|              |         |           |
                     +--------------+         +-----------+
            Virtual                   Linear                Physical
```

即软件访问的地址本质是`虚拟地址`，通过段选择子和偏移计算后得到`线性地址`，然后通过页转换为`物理地址`。

### Exercise2

阅读 https://pdos.csail.mit.edu/6.828/2018/readings/i386/s05_01.htm

### Exercise3

通过 qemu 的 `xp`，`info pg` 和 `info mem` 等指令来展示内存数据。

virtual address -> physical address：PADDR(va)
physical address -> virtual address：KADDR(pa)

### Exercise4

page table 的管理，代码实现线性地址到物理地址的 insert 和 remove。

在`kern/pmap.c`中实现如下函数：

- pgdir_walk()
- boot_map_region()
- page_lookup()
- page_remove()
- page_insert()

代码实现和细节参考代码和注释。

## Part3 内核地址空间

在 `inc/memlayout.h` 中有一个常量 `ULIM`，它可以区分用户态和内核态地址空间。[0,ULIM]是用户态，[ULIM,~]是内核态。

### Exercise5

完成 `mem_init()`函数，然后调用`check_page()`。

## 参考资料

- lab2：https://pdos.csail.mit.edu/6.828/2018/labs/lab2/
- https://www.cnblogs.com/gatsby123/p/9832223.html
- https://jiyou.github.io/blog/2018/04/19/mit.6.828/jos-lab2/
