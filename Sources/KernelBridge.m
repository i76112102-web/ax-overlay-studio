#import "KernelBridge.h"
#import "darksword_api_shim.h"
#import <libproc.h>

NSString *const DarkSwordBridgeErrorDomain = @"DarkSwordBridgeErrorDomain";

static NSString *const DarkSwordOffsetCacheKey = @"DarkSwordOffsetCache_v2";

@interface KernelBridge ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *mutableOffsetCache;
@end

@implementation KernelBridge

+ (instancetype)sharedBridge {
    static dispatch_once_t onceToken;
    static KernelBridge *bridge = nil;
    dispatch_once(&onceToken, ^{
        bridge = [[KernelBridge alloc] init];
    });
    return bridge;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSDictionary *saved = [[NSUserDefaults standardUserDefaults] dictionaryForKey:DarkSwordOffsetCacheKey];
        _mutableOffsetCache = saved.mutableCopy ?: [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSDictionary<NSString *, NSNumber *> *)offsetCache {
    return [self.mutableOffsetCache copy];
}

- (void)setOffsetValue:(uint64_t)value forKey:(NSString *)key {
    if (key.length == 0) {
        return;
    }
    self.mutableOffsetCache[key] = @(value);
    [[NSUserDefaults standardUserDefaults] setObject:[self.mutableOffsetCache copy]
                                              forKey:DarkSwordOffsetCacheKey];
}

- (NSArray<NSString *> *)requiredOffsetKeys {
    return @[@"t1sz_boot",
             @"off_proc_p_pid",
             @"off_task_itk_space",
             @"off_ipc_port_ip_kobject",
             @"off_thread_machine_contextdata"];
}

- (BOOL)validateOffsetCacheWithError:(NSError **)error {
    NSMutableArray<NSString *> *missing = [NSMutableArray array];
    for (NSString *key in [self requiredOffsetKeys]) {
        if (self.mutableOffsetCache[key] == nil) {
            [missing addObject:key];
        }
    }
    if (missing.count == 0) {
        return YES;
    }
    if (error) {
        *error = [NSError errorWithDomain:DarkSwordBridgeErrorDomain
                                    code:2
                                userInfo:@{NSLocalizedDescriptionKey:
                                               [NSString stringWithFormat:@"偏移缓存缺项: %@",
                                                [missing componentsJoinedByString:@", "]]}];
    }
    return NO;
}

- (void)initializeKernelWithCompletion:(void (^)(BOOL, NSString *))completion {
    DarkSwordAPIShim *shim = [DarkSwordAPIShim sharedShim];
    [shim bindLaraBackend];
    [shim initExploitWithCompletion:^(BOOL success, NSError *error) {
        NSString *message;
        if (success) {
            message = [NSString stringWithFormat:@"后端已绑定=%@；偏移缓存条目=%lu",
                       shim.isBackendBound ? @"YES" : @"NO",
                       (unsigned long)self.mutableOffsetCache.count];
        } else {
            message = error.localizedDescription ?: @"DarkSword 初始化失败";
        }
        if (completion) {
            completion(success, message);
        }
    }];
}

- (int)pidForProcessNamed:(NSString *)name {
    if (name.length == 0) {
        return -1;
    }
    int pids[4096] = {0};
    int count = proc_listpids(PROC_ALLPIDS, 0, pids, (int)sizeof(pids));
    if (count <= 0) {
        return -1;
    }
    char processName[MAXCOMLEN + 1] = {0};
    for (int i = 0; i < count; i++) {
        int pid = pids[i];
        if (pid <= 0) {
            continue;
        }
        memset(processName, 0, sizeof(processName));
        if (proc_name(pid, processName, sizeof(processName)) <= 0) {
            continue;
        }
        if (strcmp(processName, name.UTF8String) == 0) {
            return pid;
        }
    }
    return -1;
}

- (BOOL)injectSpringBoardWithWindowLevel:(double)windowLevel error:(NSError **)error {
    DarkSwordAPIShim *shim = [DarkSwordAPIShim sharedShim];
    if (!shim.isBackendBound) {
        if (error) {
            *error = [NSError errorWithDomain:DarkSwordBridgeErrorDomain
                                        code:1
                                    userInfo:@{NSLocalizedDescriptionKey:
                                                   @"DarkSword 后端未绑定，先完成 initializeKernel"}];
        }
        return NO;
    }
    if (![self validateOffsetCacheWithError:error]) {
        return NO;
    }
    int pid = [self pidForProcessNamed:@"SpringBoard"];
    if (pid <= 0) {
        if (error) {
            *error = [NSError errorWithDomain:DarkSwordBridgeErrorDomain
                                        code:3
                                    userInfo:@{NSLocalizedDescriptionKey:
                                                   @"当前进程枚举不到 SpringBoard"}];
        }
        return NO;
    }
    if (self.remoteInvocationBlock == nil) {
        if (error) {
            *error = [NSError errorWithDomain:DarkSwordBridgeErrorDomain
                                        code:4
                                    userInfo:@{NSLocalizedDescriptionKey:
                                                   @"remoteInvocationBlock 未绑定；接入 lara TaskRop/RemoteCall.m"}];
        }
        return NO;
    }

    NSArray<NSString *> *sequence = @[
        @"dlsym(RTLD_NEXT)",
        @"pthread_create_suspended_np",
        @"pthread_mach_thread_np",
        @"thread_get_state(flavor=6)",
        @"thread_set_state(flavor=6)",
        @"pthread_cancel",
        @"sel_registerName",
        @"objc_getClass",
        @"objc_msgSend"
    ];
    uint64_t result = 0;
    for (NSString *symbol in sequence) {
        NSError *remoteError = nil;
        BOOL ok = self.remoteInvocationBlock(pid, symbol, @[@(windowLevel)], &result, &remoteError);
        if (!ok) {
            if (error) {
                *error = remoteError ?: [NSError errorWithDomain:DarkSwordBridgeErrorDomain
                                                           code:5
                                                       userInfo:@{NSLocalizedDescriptionKey:
                                                                      [NSString stringWithFormat:@"远程调用失败: %@", symbol]}];
            }
            return NO;
        }
    }
    return YES;
}

@end
