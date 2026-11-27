#import "darksword_api_shim.h"
#import "darksword.h"

NSString *const DarkSwordShimErrorDomain = @"DarkSwordShimErrorDomain";

static void DarkSwordLogTrampoline(const char *message) {
    if (message != NULL) {
        fprintf(stderr, "[DarkSword] %s\n", message);
    }
}

static void DarkSwordProgressTrampoline(double progress) {
    if (progress >= 0.0 && progress <= 1.0) {
        fprintf(stderr, "[DarkSword] progress %.0f%%\n", progress * 100.0);
    }
}

NSError *DSError(NSInteger code, NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    return [NSError errorWithDomain:DarkSwordShimErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

@interface DarkSwordAPIShim ()
@property (nonatomic, copy, nullable) DarkSwordInitBlock initBlock;
@property (nonatomic, copy, nullable) DarkSwordKReadBlock kreadBlock;
@property (nonatomic, copy, nullable) DarkSwordKWriteBlock kwriteBlock;
@property (nonatomic, copy, nullable) DarkSwordKCallBlock kcallBlock;
@end

@implementation DarkSwordAPIShim

+ (instancetype)sharedShim {
    static dispatch_once_t onceToken;
    static DarkSwordAPIShim *shim = nil;
    dispatch_once(&onceToken, ^{
        shim = [[DarkSwordAPIShim alloc] init];
    });
    return shim;
}

- (BOOL)isBackendBound {
    return self.initBlock != nil && self.kreadBlock != nil && self.kwriteBlock != nil;
}

- (void)bindLaraBackend {
    [self setInitBlock:^BOOL(NSError **error) {
        ds_set_log_callback(DarkSwordLogTrampoline);
        ds_set_progress_callback(DarkSwordProgressTrampoline);
        int result = ds_run();
        if (result != 0 || !ds_is_ready()) {
            if (error) {
                *error = DSError(DarkSwordShimErrorBackendNotBound,
                                 @"ds_run 返回 %d，ds_is_ready=%d",
                                 result, ds_is_ready() ? 1 : 0);
            }
            return NO;
        }
        return YES;
    }];

    [self setKreadBlock:^BOOL(uint64_t address, uint64_t *value, NSError **error) {
        if (value == NULL) {
            if (error) {
                *error = DSError(DarkSwordShimErrorNullOutput, @"kread64 输出指针为空");
            }
            return NO;
        }
        if (!ds_is_ready()) {
            if (error) {
                *error = DSError(DarkSwordShimErrorBackendNotBound, @"ds_is_ready=false，先调用 ds_run");
            }
            return NO;
        }
        *value = ds_kread64(address);
        return YES;
    }];

    [self setKwriteBlock:^BOOL(uint64_t address, uint64_t value, NSError **error) {
        if (!ds_is_ready()) {
            if (error) {
                *error = DSError(DarkSwordShimErrorBackendNotBound, @"ds_is_ready=false，先调用 ds_run");
            }
            return NO;
        }
        ds_kwrite64(address, value);
        return YES;
    }];
}

- (void)setInitBlock:(DarkSwordInitBlock)block   { _initBlock = [block copy]; }
- (void)setKreadBlock:(DarkSwordKReadBlock)block { _kreadBlock = [block copy]; }
- (void)setKwriteBlock:(DarkSwordKWriteBlock)block { _kwriteBlock = [block copy]; }
- (void)setKcallBlock:(DarkSwordKCallBlock)block { _kcallBlock = [block copy]; }

- (void)initExploitWithCompletion:(void (^)(BOOL, NSError *))completion {
    DarkSwordInitBlock block = self.initBlock;
    if (block == nil) {
        NSError *error = DSError(DarkSwordShimErrorBackendNotBound,
                                 @"DarkSword init block 未绑定");
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, error); });
        }
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        BOOL success = block(&error);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(success, error); });
        }
    });
}

- (BOOL)kread64:(uint64_t)address value:(uint64_t *)value error:(NSError **)error {
    if (value == NULL) {
        if (error) {
            *error = DSError(DarkSwordShimErrorNullOutput, @"kread64 输出指针为空");
        }
        return NO;
    }
    DarkSwordKReadBlock block = self.kreadBlock;
    if (block == nil) {
        if (error) {
            *error = DSError(DarkSwordShimErrorBackendNotBound, @"kread block 未绑定");
        }
        return NO;
    }
    return block(address, value, error);
}

- (BOOL)kwrite64:(uint64_t)address value:(uint64_t)value error:(NSError **)error {
    DarkSwordKWriteBlock block = self.kwriteBlock;
    if (block == nil) {
        if (error) {
            *error = DSError(DarkSwordShimErrorBackendNotBound, @"kwrite block 未绑定");
        }
        return NO;
    }
    return block(address, value, error);
}

- (BOOL)kcall:(uint64_t)functionAddress
    arguments:(NSArray<NSNumber *> *)arguments
       result:(uint64_t *)result
        error:(NSError **)error {
    DarkSwordKCallBlock block = self.kcallBlock;
    if (block == nil) {
        if (error) {
            *error = DSError(DarkSwordShimErrorKCallUnavailable,
                             @"arm64kcall 后端未绑定；接入 lara TaskRop/RemoteCall.m 后再启用");
        }
        return NO;
    }
    return block(functionAddress, arguments ?: @[], result, error);
}

@end
