#import <Foundation/Foundation.h>
#import <mach/mach.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const CrossAppErrorDomain;

typedef NS_ENUM(NSInteger, CrossAppErrorCode) {
    CrossAppErrorBackendNotReady   = 1,
    CrossAppErrorSpringBoardAbsent = 2,
    CrossAppErrorDlsymFailed       = 3,
    CrossAppErrorThreadCreate      = 4,
    CrossAppErrorThreadGetState    = 5,
    CrossAppErrorThreadSetState    = 6,
    CrossAppErrorRemoteCallFailed  = 7,
    CrossAppErrorWindowFailed      = 8,
    CrossAppErrorUnavailable       = 9
};

// 函数指针表：全部由 lara 的 RemoteCall.m / darksword.m 在 Mac Xcode 工程里绑定。
// 未绑定时 installCrossAppOverlayWithWindowLevel:error: 返回结构化错误。
typedef struct {
    uint64_t (*remoteCall)(void *context, uint64_t functionPointer, uint64_t *args, uint32_t argCount, char *errorBuffer, uint32_t errorBufferSize);
    uint64_t (*findSymbol)(void *context, const char *imageName, const char *symbolName);
    uint64_t (*remoteAllocate)(void *context, uint64_t size);
    BOOL (*remoteWrite)(void *context, uint64_t address, const void *buffer, uint64_t size);
} CrossAppRemoteVTable;

@interface CrossAppOverlayController : NSObject

+ (instancetype)sharedController;

- (void)bindRemoteVTable:(CrossAppRemoteVTable)vtable context:(nullable void *)context;
- (BOOL)isRemoteReady;

// 真正建立跨 App 窗口：在 SpringBoard 内 alloc/init UIWindow，设置 level=10000000.0 并 makeKeyAndVisible。
- (BOOL)installCrossAppOverlayWithWindowLevel:(double)windowLevel error:(NSError **)error;
- (BOOL)removeCrossAppOverlayWithError:(NSError **)error;

// 供调试：返回当前 AX 链符号装配顺序。
- (NSArray<NSString *> *)callSequence;

@end

NS_ASSUME_NONNULL_END
