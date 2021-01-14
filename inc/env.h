/* See COPYRIGHT for copyright information. */

#ifndef JOS_INC_ENV_H
#define JOS_INC_ENV_H

#include <inc/types.h>
#include <inc/trap.h>
#include <inc/memlayout.h>

typedef int32_t envid_t;

// An environment ID 'envid_t' has three parts:
//
// +1+---------------21-----------------+--------10--------+
// |0|          Uniqueifier             |   Environment    |
// | |                                  |      Index       |
// +------------------------------------+------------------+
//                                       \--- ENVX(eid) --/
//
// The environment index ENVX(eid) equals the environment's index in the
// 'envs[]' array.  The uniqueifier distinguishes environments that were
// created at different times, but share the same environment index.
//
// All real environments are greater than 0 (so the sign bit is zero).
// envid_ts less than 0 signify errors.  The envid_t == 0 is special, and
// stands for the current environment.
// envid_t 共 32 位，第一位是标志位，标志位等于 0 表示环境，小于 0 表示 errors
// envid_t == 0 时比较特殊，表示当前的环境
// 中间 21 位是唯一标识，最后 10 位是环境序号

#define LOG2NENV		10
#define NENV			(1 << LOG2NENV)
#define ENVX(envid)		((envid) & (NENV - 1)) // 得到环境序号

// Values of env_status in struct Env 环境状态
enum {
	ENV_FREE = 0, // 空闲
	ENV_DYING, // 死亡
	ENV_RUNNABLE, // 可运行
	ENV_RUNNING, // 正在运行
	ENV_NOT_RUNNABLE // 不可运行
};

// Special environment types  环境变量类型
enum EnvType {
	ENV_TYPE_USER = 0, // 用户态环境变量
};

struct Env {
	struct Trapframe env_tf;	// Saved registers trap 需要保存的寄存器
	struct Env *env_link;		// Next free Env 下一个可用的环境
	envid_t env_id;			// Unique environment identifier 环境的id
	envid_t env_parent_id;		// env_id of this env's parent 父环境 id
	enum EnvType env_type;		// Indicates special system environments 环境类型
	unsigned env_status;		// Status of the environment 环境状态
	uint32_t env_runs;		// Number of times environment has run 环境运行的时间

	// Address space
	pde_t *env_pgdir;		// Kernel virtual address of page dir 环境的虚拟地址
};

#endif // !JOS_INC_ENV_H
