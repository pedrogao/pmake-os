#include <inc/x86.h>
#include <inc/elf.h>

/**********************************************************************
 * This a dirt simple boot loader, whose sole job is to boot
 * an ELF kernel image from the first IDE hard disk.
 *
 * DISK LAYOUT
 *  * This program(boot.S and main.c) is the bootloader.  It should
 *    be stored in the first sector of the disk.
 *
 *  * The 2nd sector onward holds the kernel image.
 *
 *  * The kernel image must be in ELF format.
 *
 * BOOT UP STEPS
 *  * when the CPU boots it loads the BIOS into memory and executes it
 *
 *  * the BIOS intializes devices, sets of the interrupt routines, and
 *    reads the first sector of the boot device(e.g., hard-drive)
 *    into memory and jumps to it.
 *
 *  * Assuming this boot loader is stored in the first sector of the
 *    hard-drive, this code takes over...
 *
 *  * control starts in boot.S -- which sets up protected mode,
 *    and a stack so C code then run, then calls bootmain()
 *
 *  * bootmain() in this file takes over, reads in the kernel and jumps to it.
 **********************************************************************/

#define SECTSIZE 512									 // 启动扇区 512 字节
#define ELFHDR ((struct Elf *)0x10000) // scratch space  ELF 文件的头部在 0x10000

void readsect(void *, uint32_t);						// 读 section
void readseg(uint32_t, uint32_t, uint32_t); // 读 segment

void bootmain(void) // 调用的第一个函数
{
	struct Proghdr *ph, *eph;

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

	// call the entry point from the ELF header
	// note: does not return!
	((void (*)(void))(ELFHDR->e_entry))(); // 调用函数了！！！这里会从软盘中读取代码，然后在内存中执行这段代码，调用的是内核的开始函数

bad:
	outw(0x8A00, 0x8A00);
	outw(0x8A00, 0x8E00);
	while (1)
		/* do nothing */;
}

// Read 'count' bytes at 'offset' from kernel into physical address 'pa'.
// Might copy more than asked
void readseg(uint32_t pa, uint32_t count, uint32_t offset)
{
	uint32_t end_pa;
	// 结束指针 = 开始指针 + count
	end_pa = pa + count;

	// round down to sector boundary
	pa &= ~(SECTSIZE - 1);

	// translate from bytes to sectors, and kernel starts at sector 1
	offset = (offset / SECTSIZE) + 1;

	// If this is too slow, we could read lots of sectors at a time.
	// We'd write more to memory than asked, but it doesn't matter --
	// we load in increasing order.
	while (pa < end_pa)
	{
		// Since we haven't enabled paging yet and we're using
		// an identity segment mapping (see boot.S), we can
		// use physical addresses directly.  This won't be the
		// case once JOS enables the MMU.
		readsect((uint8_t *)pa, offset);
		pa += SECTSIZE;
		offset++;
	}
}

void waitdisk(void)
{
	// wait for disk reaady 等待磁盘是否 ok，向 0x1F7 端口发送数据，查看接受数据是否为 0x40
	while ((inb(0x1F7) & 0xC0) != 0x40)
		/* do nothing */;
}

void readsect(void *dst, uint32_t offset)
{
	// wait for disk to be ready
	waitdisk();

	outb(0x1F2, 1); // count = 1
	outb(0x1F3, offset);
	outb(0x1F4, offset >> 8);
	outb(0x1F5, offset >> 16);
	outb(0x1F6, (offset >> 24) | 0xE0);
	outb(0x1F7, 0x20); // cmd 0x20 - read sectors

	// wait for disk to be ready
	waitdisk();

	// read a sector
	insl(0x1F0, dst, SECTSIZE / 4);
}
