#import "CrossAppOverlayController.h"
#import "RemoteCall.h"
#import "privateapi.h"
#import <dlfcn.h>
#import <pthread.h>
#import <mach/mach.h>
#import <string.h>
#import <sys/sysctl.h>
#import <stdio.h>
#import <stdlib.h>

/* iOS SDK does not ship libproc.h; these symbols live in libSystem. */
#ifndef PROC_ALLPIDS
#define PROC_ALLPIDS 0
#endif
#ifndef MAXCOMLEN
#define MAXCOMLEN 16
#endif
extern int proc_listpids(uint32_t type, uint32_t typeinfo, void *buffer, int buffersize);
extern int proc_name(int pid, void *buffer, int buffersize);

// 用户态 pid 枚举诊断（显示在状态栏）
char g_axp_pid_diag[256] = {0};

NSString *const CrossAppErrorDomain = @"CrossAppErrorDomain";

// ARM_THREAD_STATE64 = 6，与 lara TaskRop/RemoteCall.h 的 arm_thread_state64_internal 对齐。
#ifndef ARM_THREAD_STATE64
#define ARM_THREAD_STATE64 6
#endif

typedef struct {
    uint64_t __x[29];
    uint64_t __fp;
    uint64_t __lr;
    uint64_t __sp;
    uint64_t __pc;
    uint32_t __cpsr;
    uint32_t __flags;
} axp_thread_state64;

typedef void *(*axp_pthread_create_suspended_fn)(pthread_t *, const pthread_attr_t *, void *(*)(void *), void *);
typedef mach_port_t (*axp_pthread_mach_thread_fn)(pthread_t);

static void *axp_suspended_worker(void *arg) {
    (void)arg;
    return NULL;
}

@interface CrossAppOverlayController ()
@property (nonatomic, assign) CrossAppRemoteVTable vtable;
@property (nonatomic, assign) void *remoteContext;
@property (nonatomic, assign) BOOL vtableBound;
@property (nonatomic, assign) uint64_t remoteWindowAddress;
@property (nonatomic, strong) id laraRemoteCall;   // RemoteCall 实例，强持有
@property (nonatomic, assign) uint64_t remoteBubbleView;
@end

@implementation CrossAppOverlayController

+ (instancetype)sharedController {
    static dispatch_once_t onceToken;
    static CrossAppOverlayController *controller = nil;
    dispatch_once(&onceToken, ^{
        controller = [[CrossAppOverlayController alloc] init];
    });
    return controller;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        memset(&_vtable, 0, sizeof(_vtable));
        _vtableBound = NO;
        _remoteWindowAddress = 0;
        _remoteBubbleView = 0;
    }
    return self;
}

- (void)bindRemoteVTable:(CrossAppRemoteVTable)vtable context:(void *)context {
    _vtable = vtable;
    _remoteContext = context;
    _vtableBound = (vtable.remoteCall != NULL && vtable.findSymbol != NULL &&
                    vtable.remoteAllocate != NULL && vtable.remoteWrite != NULL);
}

- (BOOL)isRemoteReady {
    return self.vtableBound;
}

- (NSArray<NSString *> *)callSequence {
    return @[
        @"dlsym(RTLD_NEXT, \"pthread_create_suspended_np\")",
        @"pthread_create_suspended_np",
        @"pthread_mach_thread_np",
        @"thread_get_state(flavor=ARM_THREAD_STATE64=6)",
        @"thread_set_state(__pc -> PAC braa gadget)",
        @"pthread_cancel",
        @"remote: sel_registerName(\"alloc\")",
        @"remote: objc_getClass(\"UIWindow\")",
        @"remote: objc_msgSend(initWithFrame:)",
        @"remote: objc_msgSend(setWindowLevel: 10000000.0)",
        @"remote: objc_msgSend(makeKeyAndVisible)"
    ];
}

static NSError *CrossAppError(CrossAppErrorCode code, NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    return [NSError errorWithDomain:CrossAppErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

// 阶段 1：本进程内走一遍 AX 的 suspended-thread API 序列，确认所有符号齐备。
// 这一段不触碰内核，仅做能力探测与参数校验，任何一步失败都返回结构化错误。
- (BOOL)probeLocalSuspendedThreadSequenceWithError:(NSError **)error {
    void *handle = RTLD_NEXT;
    void *createSym = dlsym(handle, "pthread_create_suspended_np");
    void *machThreadSym = dlsym(handle, "pthread_mach_thread_np");
    if (createSym == NULL || machThreadSym == NULL) {
        createSym = dlsym(RTLD_DEFAULT, "pthread_create_suspended_np");
        machThreadSym = dlsym(RTLD_DEFAULT, "pthread_mach_thread_np");
    }
    if (createSym == NULL || machThreadSym == NULL) {
        if (error) {
            *error = CrossAppError(CrossAppErrorDlsymFailed,
                                   @"dlsym(RTLD_NEXT) 缺少 pthread_create_suspended_np=%d pthread_mach_thread_np=%d",
                                   createSym != NULL, machThreadSym != NULL);
        }
        return NO;
    }

    axp_pthread_create_suspended_fn createFn = (axp_pthread_create_suspended_fn)createSym;
    axp_pthread_mach_thread_fn machThreadFn = (axp_pthread_mach_thread_fn)machThreadSym;

    pthread_t thread = 0;
    int createResult = createFn(&thread, NULL, axp_suspended_worker, NULL);
    if (createResult != 0) {
        if (error) {
            *error = CrossAppError(CrossAppErrorThreadCreate,
                                   @"pthread_create_suspended_np 返回 %d", createResult);
        }
        return NO;
    }

    mach_port_t machThread = machThreadFn(thread);
    if (machThread == MACH_PORT_NULL) {
        pthread_cancel(thread);
        if (error) {
            *error = CrossAppError(CrossAppErrorThreadCreate, @"pthread_mach_thread_np 返回 MACH_PORT_NULL");
        }
        return NO;
    }

    axp_thread_state64 state;
    memset(&state, 0, sizeof(state));
    mach_msg_type_number_t count = ARM_THREAD_STATE64_COUNT;
    kern_return_t kr = thread_get_state(machThread, ARM_THREAD_STATE64,
                                        (thread_state_t)&state, &count);
    if (kr != KERN_SUCCESS) {
        pthread_cancel(thread);
        if (error) {
            *error = CrossAppError(CrossAppErrorThreadGetState,
                                   @"thread_get_state(flavor=6) 返回 0x%x", kr);
        }
        return NO;
    }

    // 只验证 set_state 通道可用；PC 保持原值，不在本进程改执行流。
    kr = thread_set_state(machThread, ARM_THREAD_STATE64,
                          (thread_state_t)&state, count);
    if (kr != KERN_SUCCESS) {
        pthread_cancel(thread);
        if (error) {
            *error = CrossAppError(CrossAppErrorThreadSetState,
                                   @"thread_set_state(flavor=6) 返回 0x%x", kr);
        }
        return NO;
    }

    pthread_cancel(thread);
    return YES;
}

// 阶段 2：远程调用封装。所有远程执行通过 vtable；未绑定返回结构化错误。
- (uint64_t)remoteCallFunction:(uint64_t)functionPointer
                          args:(uint64_t *)args
                     argCount:(uint32_t)argCount
                         error:(NSError **)error {
    if (!self.vtableBound || self.vtable.remoteCall == NULL) {
        if (error) {
            *error = CrossAppError(CrossAppErrorUnavailable,
                                   @"remote vtable 未绑定；在 Mac 工程里接入 lara TaskRop/RemoteCall.m");
        }
        return 0;
    }
    char errBuf[256] = {0};
    uint64_t result = self.vtable.remoteCall(self.remoteContext, functionPointer,
                                             args, argCount, errBuf, sizeof(errBuf));
    if (errBuf[0] != '\0') {
        if (error) {
            *error = CrossAppError(CrossAppErrorRemoteCallFailed, @"%s", errBuf);
        }
        return 0;
    }
    return result;
}

- (uint64_t)remoteFindSymbol:(const char *)imageName symbol:(const char *)symbolName error:(NSError **)error {
    if (!self.vtableBound || self.vtable.findSymbol == NULL) {
        if (error) {
            *error = CrossAppError(CrossAppErrorUnavailable, @"remote findSymbol 未绑定");
        }
        return 0;
    }
    uint64_t address = self.vtable.findSymbol(self.remoteContext, imageName, symbolName);
    if (address == 0 && error) {
        *error = CrossAppError(CrossAppErrorRemoteCallFailed,
                               @"远程镜像 %s 找不到符号 %s", imageName, symbolName);
    }
    return address;
}

- (BOOL)bindLaraRemoteCallForSpringBoardWithError:(NSError **)error {
    // 用户态拿 SpringBoard pid，三路兜底；自签沙盒下 proc_listpids 可能被限制。
    pid_t sbPid = -1;
    char nm[64] = {0};

    // 路线 1：proc_listpids + proc_name
    int pids[4096] = {0};
    int pcount = proc_listpids(PROC_ALLPIDS, 0, pids, (int)sizeof(pids));
    for (int i = 0; pcount > 0 && i < pcount; i++) {
        if (pids[i] <= 0) continue;
        memset(nm, 0, sizeof(nm));
        if (proc_name(pids[i], nm, sizeof(nm)) <= 0) continue;
        if (strcmp(nm, "SpringBoard") == 0) { sbPid = (pid_t)pids[i]; break; }
    }
    snprintf(g_axp_pid_diag, sizeof(g_axp_pid_diag), "listpids n=%d sb=%d", pcount, sbPid);

    // 路线 2：sysctl(KERN_PROC_ALL)
    if (sbPid <= 0) {
        int mib[3] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL };
        size_t sz = 0;
        if (sysctl(mib, 3, NULL, &sz, NULL, 0) == 0 && sz > 0) {
            struct kinfo_proc *procs = (struct kinfo_proc *)malloc(sz);
            if (procs) {
                size_t sz2 = sz;
                if (sysctl(mib, 3, procs, &sz2, NULL, 0) == 0) {
                    int cnt = (int)(sz2 / sizeof(struct kinfo_proc));
                    for (int i = 0; i < cnt; i++) {
                        memset(nm, 0, sizeof(nm));
                        proc_name(procs[i].kp_proc.p_pid, nm, sizeof(nm));
                        if (strcasecmp(nm, "SpringBoard") == 0) { sbPid = procs[i].kp_proc.p_pid; break; }
                    }
                }
                free(procs);
            }
        }
        snprintf(g_axp_pid_diag, sizeof(g_axp_pid_diag), "sysctl sb=%d", sbPid);
    }

    // 路线 3：直接扫常见 pid 区间（SpringBoard 通常 pid < 500）
    if (sbPid <= 0) {
        for (int pid = 1; pid < 1000; pid++) {
            memset(nm, 0, sizeof(nm));
            if (proc_name(pid, nm, sizeof(nm)) > 0 && strcmp(nm, "SpringBoard") == 0) {
                sbPid = pid; break;
            }
        }
        snprintf(g_axp_pid_diag, sizeof(g_axp_pid_diag), "brute sb=%d", sbPid);
    }

    printf("(crossapp) SpringBoard pid (userspace) = %d [%s]\n", sbPid, g_axp_pid_diag);
    [RemoteCall setTargetPidOverride:(sbPid > 0 ? sbPid : 0)];

    // 必须在 ds_run() 成功之后调用；RemoteCall 依赖内核 R/W 拿目标 task port。
    RemoteCall *rc = [[RemoteCall alloc] initWithProcess:@"SpringBoard" useMigFilterBypass:NO];
    if (rc == nil) {
        NSString *detail = [RemoteCall lastInitError] ?: @"RemoteCall(SpringBoard) 返回 nil";
        NSString *pidInfo = [NSString stringWithUTF8String:g_axp_pid_diag] ?: @"";
        if (error) {
            *error = CrossAppError(CrossAppErrorSpringBoardAbsent, @"%@ [%@]", detail, pidInfo);
        }
        return NO;
    }
    self.laraRemoteCall = rc;
    return YES;
}

- (BOOL)installLaraSpringBoardOverlayWithWindowLevel:(double)windowLevel error:(NSError **)error {
    RemoteCall *proc = (RemoteCall *)self.laraRemoteCall;
    if (proc == nil) {
        if (error) {
            *error = CrossAppError(CrossAppErrorBackendNotReady,
                                   @"RemoteCall 未绑定；先调用 bindLaraRemoteCallForSpringBoardWithError:");
        }
        return NO;
    }

    // 参考 lara rc.m::freakywindow：拿到 SpringBoard 自己的 keyWindow，
    // 把悬浮视图挂进去。这个视图属于 SpringBoard 进程，天然悬浮在所有 App 之上。
    uint64_t clsUIApplication = remote_getClass(proc, "UIApplication");
    uint64_t clsUIView        = remote_getClass(proc, "UIView");
    uint64_t clsUIColor       = remote_getClass(proc, "UIColor");
    if (clsUIApplication == 0 || clsUIView == 0 || clsUIColor == 0) {
        if (error) {
            *error = CrossAppError(CrossAppErrorWindowFailed,
                                   @"SpringBoard 内解析 UIApplication/UIView/UIColor 失败");
        }
        return NO;
    }

    uint64_t selSharedApp = remote_sel(proc, "sharedApplication");
    uint64_t selKeyWindow = remote_sel(proc, "keyWindow");
    uint64_t selWindows   = remote_sel(proc, "windows");
    uint64_t selFirst     = remote_sel(proc, "firstObject");
    uint64_t selDelegate  = remote_sel(proc, "delegate");
    uint64_t selWindow    = remote_sel(proc, "window");

    uint64_t app = remote_msg(proc, clsUIApplication, selSharedApp, 0, 0, 0, 0);
    uint64_t window = 0;
    if (app != 0) {
        window = remote_msg(proc, app, selKeyWindow, 0, 0, 0, 0);
        if (window == 0) {
            uint64_t windows = remote_msg(proc, app, selWindows, 0, 0, 0, 0);
            if (windows != 0) {
                window = remote_msg(proc, windows, selFirst, 0, 0, 0, 0);
            }
        }
        if (window == 0) {
            uint64_t delegate = remote_msg(proc, app, selDelegate, 0, 0, 0, 0);
            if (delegate != 0) {
                window = remote_msg(proc, delegate, selWindow, 0, 0, 0, 0);
            }
        }
    }
    if (window == 0) {
        if (error) {
            *error = CrossAppError(CrossAppErrorWindowFailed, @"SpringBoard 内未找到可用 keyWindow");
        }
        return NO;
    }

    // 若已挂过，先移除，避免重复叠加。
    if (self.remoteBubbleView != 0) {
        uint64_t selRemove = remote_sel(proc, "removeFromSuperview");
        uint64_t selPerform = remote_sel(proc, "performSelectorOnMainThread:withObject:waitUntilDone:");
        remote_msg(proc, self.remoteBubbleView, selPerform, selRemove, 0, 1, 0);
        self.remoteBubbleView = 0;
    }

    // alloc/init 一个 UIView 作为悬浮球，参考 lara rc.m 的 remote_msg 模式。
    uint64_t bubble = RemoteArbCall(proc, objc_alloc, clsUIView);
    if (bubble == 0) {
        if (error) {
            *error = CrossAppError(CrossAppErrorWindowFailed, @"SpringBoard 内 objc_alloc(UIView) 返回 0");
        }
        return NO;
    }
    uint64_t selInitFrame = remote_sel(proc, "initWithFrame:");
    uint64_t selSetFrame  = remote_sel(proc, "setFrame:");

    // 用 CGRectZero init（remote_msg 只能传整型寄存器，frame 用 setFrame 补）。
    bubble = remote_msg(proc, bubble, selInitFrame, 0, 0, 0, 0);
    if (bubble == 0) {
        if (error) {
            *error = CrossAppError(CrossAppErrorWindowFailed, @"SpringBoard 内 initWithFrame: 返回 0");
        }
        return NO;
    }

    // 悬浮球尺寸/位置：屏幕右上角区域，60x60 圆形。
    remote_setCGRect(proc, bubble, selSetFrame, CGRectMake(300, 140, 60, 60));

    uint64_t selSetBg      = remote_sel(proc, "setBackgroundColor:");
    uint64_t selSetHidden  = remote_sel(proc, "setHidden:");
    uint64_t selSetUserInt = remote_sel(proc, "setUserInteractionEnabled:");
    uint64_t selAddSubview = remote_sel(proc, "addSubview:");
    uint64_t selPerform    = remote_sel(proc, "performSelectorOnMainThread:withObject:waitUntilDone:");

    // UIColor colorWithRed:green:blue:alpha: 需要 double 寄存器，改用系统蓝色常量选择器。
    uint64_t selBlueColor = remote_sel(proc, "blueColor");
    uint64_t color = remote_msg(proc, clsUIColor, selBlueColor, 0, 0, 0, 0);
    if (color != 0) {
        remote_msg(proc, bubble, selSetBg, color, 0, 0, 0);
    }
    remote_msg(proc, bubble, selSetHidden, 0, 0, 0, 0);
    remote_msg(proc, bubble, selSetUserInt, 1, 0, 0, 0);

    // 在主线程把悬浮球挂到 SpringBoard keyWindow。
    remote_msg(proc, window, selPerform, selAddSubview, bubble, 1, 0);
    remote_msg(proc, window, selPerform, remote_sel(proc, "bringSubviewToFront:"), bubble, 1, 0);

    self.remoteBubbleView = bubble;
    self.remoteWindowAddress = window;
    return YES;
}

- (BOOL)installCrossAppOverlayWithWindowLevel:(double)windowLevel error:(NSError **)error {
    // 首选：lara RemoteCall 直连 SpringBoard（真正落地的跨 App 通道）。
    if (self.laraRemoteCall == nil) {
        NSError *bindError = nil;
        if (![self bindLaraRemoteCallForSpringBoardWithError:&bindError]) {
            if (error) {
                *error = bindError;
            }
            return NO;
        }
    }
    return [self installLaraSpringBoardOverlayWithWindowLevel:windowLevel error:error];
}

- (BOOL)installCrossAppOverlayViaSyscallChainWithWindowLevel:(double)windowLevel error:(NSError **)error {
    if (![self probeLocalSuspendedThreadSequenceWithError:error]) {
        return NO;
    }
    if (!self.vtableBound) {
        if (error) {
            *error = CrossAppError(CrossAppErrorUnavailable,
                                   @"AX syscall 序列已就绪，但 remote vtable 未绑定；跨 App 窗口尚未落地");
        }
        return NO;
    }

    // 解析 SpringBoard 内 Foundation/UIKit 关键符号。
    uint64_t pPthreadCreateSuspended = [self remoteFindSymbol:"/usr/lib/libsystem_c.dylib"
                                                       symbol:"pthread_create_suspended_np" error:error];
    if (pPthreadCreateSuspended == 0) return NO;
    uint64_t pPthreadMachThread = [self remoteFindSymbol:"/usr/lib/libsystem_c.dylib"
                                                  symbol:"pthread_mach_thread_np" error:error];
    if (pPthreadMachThread == 0) return NO;
    uint64_t pThreadGetState = [self remoteFindSymbol:"/usr/lib/libsystem_c.dylib"
                                               symbol:"thread_get_state" error:error];
    if (pThreadGetState == 0) return NO;
    uint64_t pThreadSetState = [self remoteFindSymbol:"/usr/lib/libsystem_c.dylib"
                                               symbol:"thread_set_state" error:error];
    if (pThreadSetState == 0) return NO;
    uint64_t pSelRegister = [self remoteFindSymbol:"/usr/lib/libobjc.A.dylib"
                                            symbol:"sel_registerName" error:error];
    if (pSelRegister == 0) return NO;
    uint64_t pGetClass = [self remoteFindSymbol:"/usr/lib/libobjc.A.dylib"
                                         symbol:"objc_getClass" error:error];
    if (pGetClass == 0) return NO;
    uint64_t pMsgSend = [self remoteFindSymbol:"/usr/lib/libobjc.A.dylib"
                                       symbol:"objc_msgSend" error:error];
    if (pMsgSend == 0) return NO;

    // 按 AX 的 suspended-thread 序列在 SpringBoard 内开一个受控线程并把 PC 改到 gadget。
    uint64_t threadArgs[4] = {0, 0, 0, 0};
    uint64_t remoteThread = [self remoteCallFunction:pPthreadCreateSuspended args:threadArgs argCount:4 error:error];
    if (remoteThread == 0) return NO;
    uint64_t machThreadArgs[1] = {remoteThread};
    uint64_t machThread = [self remoteCallFunction:pPthreadMachThread args:machThreadArgs argCount:1 error:error];
    if (machThread == 0) {
        if (error) {
            *error = CrossAppError(CrossAppErrorThreadCreate, @"远程 pthread_mach_thread_np 返回 0");
        }
        return NO;
    }

    uint64_t stateArgs[5] = {machThread, ARM_THREAD_STATE64, 0, 0, 0};
    [self remoteCallFunction:pThreadGetState args:stateArgs argCount:5 error:error];
    // stateArgs[2] 由 remoteCall 回填远程 state 地址；若后端不回填则沿用 AX 的 trojanMem 通道。
    uint64_t remoteState = stateArgs[2];
    if (remoteState == 0) {
        remoteState = self.vtable.remoteAllocate(self.remoteContext, sizeof(axp_thread_state64));
    }
    if (remoteState == 0) {
        if (error) {
            *error = CrossAppError(CrossAppErrorThreadGetState, @"远程 thread state 缓冲区分配失败");
        }
        return NO;
    }
    [self remoteCallFunction:pThreadSetState args:(uint64_t[]){machThread, ARM_THREAD_STATE64, remoteState, 0, 0}
                    argCount:5 error:error];

    // 在 SpringBoard 内构造 UIWindow 并设成 AX 使用的窗口层级。
    // sel_registerName / objc_getClass / objc_msgSend 全部走远程调用。
    uint64_t selAlloc = 0, selInitFrame = 0, selSetLevel = 0, selMakeVisible = 0;
    uint64_t selArgs[1] = {0};
    const char *names[] = {"alloc", "initWithFrame:", "setWindowLevel:", "makeKeyAndVisible"};
    uint64_t *sels[] = {&selAlloc, &selInitFrame, &selSetLevel, &selMakeVisible};
    for (int i = 0; i < 4; i++) {
        selArgs[0] = self.vtable.remoteAllocate(self.remoteContext, strlen(names[i]) + 1);
        if (selArgs[0] == 0 || !self.vtable.remoteWrite(self.remoteContext, selArgs[0], names[i], strlen(names[i]) + 1)) {
            if (error) {
                *error = CrossAppError(CrossAppErrorRemoteCallFailed, @"远程写入 selector %s 失败", names[i]);
            }
            return NO;
        }
        *sels[i] = [self remoteCallFunction:pSelRegister args:selArgs argCount:1 error:error];
        if (*sels[i] == 0) return NO;
    }

    selArgs[0] = self.vtable.remoteAllocate(self.remoteContext, strlen("UIWindow") + 1);
    if (selArgs[0] == 0 || !self.vtable.remoteWrite(self.remoteContext, selArgs[0], "UIWindow", strlen("UIWindow") + 1)) {
        if (error) {
            *error = CrossAppError(CrossAppErrorWindowFailed, @"远程写入 UIWindow 类名失败");
        }
        return NO;
    }
    uint64_t windowClass = [self remoteCallFunction:pGetClass args:selArgs argCount:1 error:error];
    if (windowClass == 0) {
        if (error) {
            *error = CrossAppError(CrossAppErrorWindowFailed, @"SpringBoard 内 objc_getClass(UIWindow) 返回 0");
        }
        return NO;
    }

    uint64_t window = [self remoteCallFunction:pMsgSend args:(uint64_t[]){windowClass, selAlloc} argCount:2 error:error];
    if (window == 0) {
        if (error) {
            *error = CrossAppError(CrossAppErrorWindowFailed, @"远程 [UIWindow alloc] 返回 0");
        }
        return NO;
    }

    // CGRectZero 以 4 个 double 传入，覆盖整个屏幕由 SpringBoard 自身 bounds 决定。
    uint64_t frameArgs[5] = {window, selInitFrame, 0, 0, 0};
    window = [self remoteCallFunction:pMsgSend args:frameArgs argCount:5 error:error];
    if (window == 0) {
        if (error) {
            *error = CrossAppError(CrossAppErrorWindowFailed, @"远程 initWithFrame: 返回 0");
        }
        return NO;
    }

    uint64_t levelBits = 0;
    memcpy(&levelBits, &windowLevel, sizeof(double));
    [self remoteCallFunction:pMsgSend args:(uint64_t[]){window, selSetLevel, levelBits} argCount:3 error:error];
    [self remoteCallFunction:pMsgSend args:(uint64_t[]){window, selMakeVisible} argCount:2 error:error];

    self.remoteWindowAddress = window;
    return YES;
}

- (BOOL)removeCrossAppOverlayWithError:(NSError **)error {
    // lara RemoteCall 路径：在主线程把悬浮球从 SpringBoard window 移除。
    if (self.laraRemoteCall != nil && self.remoteBubbleView != 0) {
        RemoteCall *proc = (RemoteCall *)self.laraRemoteCall;
        uint64_t selRemove = remote_sel(proc, "removeFromSuperview");
        uint64_t selPerform = remote_sel(proc, "performSelectorOnMainThread:withObject:waitUntilDone:");
        remote_msg(proc, self.remoteBubbleView, selPerform, selRemove, 0, 1, 0);
        self.remoteBubbleView = 0;
        self.remoteWindowAddress = 0;
        return YES;
    }
    if (self.remoteWindowAddress == 0) {
        if (error) {
            *error = CrossAppError(CrossAppErrorUnavailable, @"当前没有已安装的跨 App 窗口");
        }
        return NO;
    }
    uint64_t pMsgSend = [self remoteFindSymbol:"/usr/lib/libobjc.A.dylib" symbol:"objc_msgSend" error:error];
    if (pMsgSend == 0) return NO;
    uint64_t selHidden = 0;
    uint64_t selArgs[1] = {0};
    const char *name = "setHidden:";
    selArgs[0] = self.vtable.remoteAllocate(self.remoteContext, strlen(name) + 1);
    if (selArgs[0] == 0 || !self.vtable.remoteWrite(self.remoteContext, selArgs[0], name, strlen(name) + 1)) {
        if (error) {
            *error = CrossAppError(CrossAppErrorRemoteCallFailed, @"远程写入 setHidden: 失败");
        }
        return NO;
    }
    uint64_t pSelRegister = [self remoteFindSymbol:"/usr/lib/libobjc.A.dylib" symbol:"sel_registerName" error:error];
    if (pSelRegister == 0) return NO;
    selHidden = [self remoteCallFunction:pSelRegister args:selArgs argCount:1 error:error];
    if (selHidden == 0) return NO;
    [self remoteCallFunction:pMsgSend args:(uint64_t[]){self.remoteWindowAddress, selHidden, 1} argCount:3 error:error];
    self.remoteWindowAddress = 0;
    return YES;
}

@end
