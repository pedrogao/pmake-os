# lab4

实现多核、多任务。

- 开启多处理器。现代处理器一般都是多核的，这样每个 CPU 能同时运行不同进程，实现并行。需要用锁解决多 CPU 的竞争。介绍了 spin lock 和 sleep lock，并给出了 spin lock 的实现。
- 实现进程调度算法。
- 实现写时拷贝 fork（进程创建）。
- 实现进程间通信。

## 参考资料

- https://pdos.csail.mit.edu/6.828/2018/labs/lab4/
- https://www.cnblogs.com/gatsby123/p/9930630.html
