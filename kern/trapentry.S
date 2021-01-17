/* See COPYRIGHT for copyright information. */

#include <inc/mmu.h>
#include <inc/memlayout.h>
#include <inc/trap.h>

#include <kern/picirq.h>


###################################################################
# exceptions/interrupts
###################################################################

/* TRAPHANDLER defines a globally-visible function for handling a trap.
 * It pushes a trap number onto the stack, then jumps to _alltraps.
 * Use TRAPHANDLER for traps where the CPU automatically pushes an error code.
 *
 * You shouldn't call a TRAPHANDLER function from C, but you may
 * need to _declare_ one in C (for instance, to get a function pointer
 * during IDT setup).  You can declare the function with
 *   void NAME();
 * where NAME is the argument passed to TRAPHANDLER.
 */
#define TRAPHANDLER(name, num)						\
	.globl name;		/* define global symbol for 'name' */	\
	.type name, @function;	/* symbol type is function */		\
	.align 2;		/* align function definition */		\
	name:			/* function starts here */		\
	pushl $(num);							\
	jmp _alltraps

/* Use TRAPHANDLER_NOEC for traps where the CPU doesn't push an error code.
 * It pushes a 0 in place of the error code, so the trap frame has the same
 * format in either case.
 */
#define TRAPHANDLER_NOEC(name, num)					\
	.globl name;							\
	.type name, @function;						\
	.align 2;							\
	name:								\
	pushl $0;							\
	pushl $(num);							\
	jmp _alltraps

.text

/*
 * Lab 3: Your code here for generating entry points for the different traps.
 */

	TRAPHANDLER_NOEC(DIVIDE, T_DIVIDE)
	TRAPHANDLER_NOEC(DEBUG, T_DEBUG)
	TRAPHANDLER_NOEC(NMI, T_NMI)
	TRAPHANDLER_NOEC(BRKPT, T_BRKPT)
	TRAPHANDLER_NOEC(OFLOW, T_OFLOW)
	TRAPHANDLER_NOEC(BOUND, T_BOUND)
	TRAPHANDLER_NOEC(ILLOP, T_ILLOP)
	TRAPHANDLER_NOEC(DEVICE, T_DEVICE)
	TRAPHANDLER(DBLFLT, T_DBLFLT)
	TRAPHANDLER(TSS, T_TSS)
	TRAPHANDLER(SEGNP, T_SEGNP)
	TRAPHANDLER(STACK, T_STACK)
	TRAPHANDLER(GPFLT, T_GPFLT)
	TRAPHANDLER(PGFLT, T_PGFLT)
	TRAPHANDLER_NOEC(FPERR, T_FPERR)
	TRAPHANDLER(ALIGN, T_ALIGN)
	TRAPHANDLER_NOEC(MCHK, T_MCHK)
	TRAPHANDLER_NOEC(SIMDERR, T_SIMDERR)
	TRAPHANDLER_NOEC(SYSCALL, T_SYSCALL)
	TRAPHANDLER_NOEC(DEFAULT, T_DEFAULT)

	TRAPHANDLER_NOEC(vector32, IRQ_OFFSET + IRQ_TIMER)
	TRAPHANDLER_NOEC(vector33, IRQ_OFFSET + IRQ_KBD)
	TRAPHANDLER_NOEC(vector36, IRQ_OFFSET + IRQ_SERIAL)
	TRAPHANDLER_NOEC(vector39, IRQ_OFFSET + IRQ_SPURIOUS)
	TRAPHANDLER_NOEC(vector46, IRQ_OFFSET + IRQ_IDE)
	TRAPHANDLER_NOEC(vector51, IRQ_OFFSET + IRQ_ERROR)

/*
 * Lab 3: Your code here for _alltraps
 */

	/* 参考inc/trap.h中的Trapframe结构。tf_ss，tf_esp，tf_eflags，tf_cs，tf_eip，tf_err在中断发生时由处理器压入，所以现在只需要压入剩下寄存器（%ds,%es,通用寄存器）*/
	/* 切换到内核数据段 */
.globl _alltraps
_alltraps:
	# Build trap frame.
	pushl %ds
	pushl %es
	pushal 
	# Set up data segments.
	# set up processor to run kernel C code, trap()
	movw $(GD_KD), %ax
	movw %ax, %ds
	movw %ax, %es

	# Call trap(tf), where tf=%esp
	pushl %esp       # create an argument for trap(tf)
	call trap