#ifndef JOS_INC_SYSCALL_H
#define JOS_INC_SYSCALL_H

/* system call numbers 系统调用序号 */ 
enum {
	SYS_cputs = 0, // c puts char
	SYS_cgetc, // c gets char
	SYS_getenvid, // get env id
	SYS_env_destroy, // env destroy
	NSYSCALLS // 非系统调用
};

#endif /* !JOS_INC_SYSCALL_H */
