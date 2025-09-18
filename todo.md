# Lua Kernel / Libkernel Checklist

## Filesystem

- [ ~ ] Build base FS tree (`/`, `/dev`, etc.)
- [ X ] Implement `/dev/zero` and `/dev/random` reads
- [ ~ ] Implement file permissions (`?`, `-`, `r`, `w`, `v`)
- [ ] Ensure file creation and writing respects permissions
- [ ] Optional: support for additional `/dev` devices (`/dev/null`, `/dev/tty`)

## Processes

- [ ] Coroutine-based process scheduler
- [ ] `new_process` creation from Lua function or file path
- [ ] `processes.step` handles yields and returns correctly
- [ ] `processes:die` removes process and rebuilds PID table
- [ ] Child process environments (for future user/CWD separation)
- [ ] Error handling for failed coroutine resumes

## Kernel / Core

- [ ] Boot time tracking (`boot_time`, file timestamps)
- [ ] Global root FS object (`_G.__root`) and FS library (`_G.__fs`)
- [ ] Basic system globals (`_G.is_su`, `_G.cwd`)
- [ ] Event loop handling (`os.pullEventRaw` integration)
- [ ] Temporary shell integration for testing
- [ ] Optional: wait queue / timed yields for processes
- [ ] Optional: IPC hooks for future multi-process communication

## Libkernel / System Library

- [ ] Table utilities (like `table.find`)
- [ ] File read/write abstractions (`node.read`, `node.write`)
- [ ] Permission checking helpers
- [ ] Process management helpers (`runFile`, `new_process`, `step`, `die`)
- [ ] Environment setup for processes
- [ ] Optional: hooks for user-space libraries
