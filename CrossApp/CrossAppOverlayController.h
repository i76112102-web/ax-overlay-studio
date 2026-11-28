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

// 用 lara 的 RemoteCall 连接 SpringBoard（内核就绪后可用）。这是真正落地的跨 App 通道。
// 内部执行 [[RemoteCall alloc] initWithProcess:@"SpringBoard" useMigFilterBypass:NO]，
// 并把返回的实例作为 remote context 绑定。失败返回 NO 并写 error。
- (BOOL)bindLaraRemoteCallForSpringBoardWithError:(NSError **)error;

// 用已绑定的 RemoteCall 在 SpringBoard 内创建跨 App 悬浮视图。
// 优先创建独立 UIWindow 并 setWindowLevel:；若 SpringBoard 无可用 scene，
// 则退回挂到 SpringBoard keyWindow（lara rc.m freakywindow 已验证路径）。
- (BOOL)installLaraSpringBoardOverlayWithWindowLevel:(double)windowLevel error:(NSError **)error;

// 真正建立跨 App 窗口：在 SpringBoard 内 alloc/init UIWindow，设置 level=10000000.0 并 makeKeyAndVisible。
- (BOOL)installCrossAppOverlayWithWindowLevel:(double)windowLevel error:(NSError **)error;
- (BOOL)removeCrossAppOverlayWithError:(NSError **)error;

// step19: 实时移动跨 App 悬浮球到屏幕坐标（App 内拖动垫 → kcall setFrame）。
// 球本身在 SpringBoard 进程，位置更新通过 NSInvocation 主线程 setFrame: 落地。
- (BOOL)moveOverlayToPoint:(CGPoint)point error:(NSError **)error;

// 当前球中心坐标（本地缓存），供拖动垫初始化。
- (CGPoint)currentOverlayCenter;

// step25: hitTest 探针用的 pan recognizer 地址（远程对象）
@property (nonatomic, assign) uint64_t axHitPan;

// 供调试：返回当前 AX 链符号装配顺序。
- (NSArray<NSString *> *)callSequence;

@end

NS_ASSUME_NONNULL_END
