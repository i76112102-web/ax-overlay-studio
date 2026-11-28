#import "AXHIDTouchManager.h"
#import <dlfcn.h>
#import <syslog.h>
#import <dispatch/dispatch.h>
#import <unistd.h>
#import <CoreFoundation/CoreFoundation.h>
#import <math.h>

@interface AXHIDTouchManager ()
@property (nonatomic, copy) CGPoint (^centerProvider)(void);
@property (nonatomic, copy) void (^moveHandler)(CGPoint);
@property (nonatomic, copy) void (^tapHandler)(void);
@property (nonatomic, readwrite) BOOL running;
@end

typedef void (*AXHIDRegisterFn)(void *callback);
typedef CGPoint (*AXHIDGetPointFn)(void *event, void *path);
typedef int (*AXIOHIDGetTypeFn)(void *event);

static AXHIDGetPointFn sGetPoint = NULL;
static AXIOHIDGetTypeFn sGetType = NULL;
static AXHIDTouchManager *sManager = nil;
static BOOL sDragging = NO;
static CGPoint sDragOffset = {0, 0};
static CGPoint sLastPoint = {0, 0};
static int sDumpBudget = 12;
static BOOL sHasDrag = NO;
static CFAbsoluteTime sLastMoveTime = 0;

static void AXHIDLog(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *line = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    syslog(LOG_NOTICE, "[AXHID] %s", line.UTF8String);

    static NSFileHandle *fh = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *doc = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *path = [doc stringByAppendingPathComponent:@"axhid.log"];
        [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
        fh = [NSFileHandle fileHandleForWritingAtPath:path];
    });
    NSString *stamped = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], line];
    @synchronized (fh) {
        [fh seekToEndOfFile];
        [fh writeData:[stamped dataUsingEncoding:NSUTF8StringEncoding]];
        [fh synchronizeFile];
    }
}

// AX 主程序坐标提取点 0x10092cd38 的等价写法（AX_HID_SIGNATURE_FINDINGS.md）：
//   ldr x1, [x21, #0x10]      ; digitizer path
//   ldr x0, [x19, #0x20]      ; event（callback 第4参数 x3）
//   bl  BKSHIDEventGetHitTestPointFromDigitizerEventForPathEvent
//   fmov d8, d0 / fmov d9, d1 ; 全局 x/y
// path 不是 callback 参数，运行时对 a0/a1/a2 及其 +0x10 做候选探测。
static void axhid_callback(void *a0, void *a1, void *a2, void *a3, void *a4, void *a5) {
    AXHIDTouchManager *me = sManager;
    if (me == nil || sGetPoint == NULL) return;

    // 静态反汇编确认（_re\AX_HID_SIGNATURE_FINDINGS.md）：
    //   callback 第4参数 x3 = event（入口 str x3,[x19,#0x20]，随后传 IOHIDEventGetType）
    //   GetHitTestPoint(event, path)，path 是 callback 自己构造的对象，
    //   未绑定到 callback 的 a0/a1/a2，只能运行时候选探测。
    void *event = a3;
    if (event == NULL) return;
    if (sGetType != NULL && sGetType(event) != 0xb) return; // kIOHIDEventTypeDigitizer

    void *paths[6] = {
        a0, a1, a2,
        a0 ? *(void **)((char *)a0 + 0x10) : NULL,
        a1 ? *(void **)((char *)a1 + 0x10) : NULL,
        a2 ? *(void **)((char *)a2 + 0x10) : NULL
    };
    CGPoint chosen = {CGFLOAT_MAX, CGFLOAT_MAX};
    int chosenIdx = -1;
    void *chosenPath = NULL;

    for (int i = 0; i < 6; i++) {
        if (paths[i] == NULL) continue;
        CGPoint p = sGetPoint(event, paths[i]);
        if (isfinite(p.x) && isfinite(p.y) && p.x >= 0 && p.y >= 0 && p.x <= 3000 && p.y <= 3000) {
            chosen = p;
            chosenIdx = i;
            chosenPath = paths[i];
            break;
        }
    }

    if (sDumpBudget > 0) {
        sDumpBudget--;
        AXHIDLog(@"cb event=%p type=%d path=%p idx=%d pt=(%.1f,%.1f)",
                 event, sGetType ? sGetType(event) : -1, chosenPath, chosenIdx, chosen.x, chosen.y);
    }

    if (chosenIdx < 0) return;

    CGPoint center = me.centerProvider ? me.centerProvider() : CGPointMake(-1000, -1000);
    CGFloat dx = chosen.x - center.x;
    CGFloat dy = chosen.y - center.y;
    BOOL inside = (dx * dx + dy * dy) <= 45.0 * 45.0;

    if (inside && !sDragging) {
        sDragging = YES;
        sDragOffset = CGPointMake(center.x - chosen.x, center.y - chosen.y);
        sHasDrag = YES;
        AXHIDLog(@"DOWN hit ball center=(%.1f,%.1f) pt=(%.1f,%.1f)", center.x, center.y, chosen.x, chosen.y);
    }

    if (sDragging) {
        CGPoint target = CGPointMake(chosen.x + sDragOffset.x, chosen.y + sDragOffset.y);
        sLastPoint = target;
        CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
        if (now - sLastMoveTime >= 0.016) {
            sLastMoveTime = now;
            void (^move)(CGPoint) = me.moveHandler;
            if (move) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    move(target);
                });
            }
            AXHIDLog(@"MOVE target=(%.1f,%.1f)", target.x, target.y);
        }
    }
}

@implementation AXHIDTouchManager

+ (instancetype)sharedManager {
    static dispatch_once_t once;
    static AXHIDTouchManager *m = nil;
    dispatch_once(&once, ^{
        m = [[AXHIDTouchManager alloc] init];
    });
    return m;
}

- (BOOL)startWithCenterProvider:(CGPoint (^)(void))centerProvider
                    moveHandler:(void (^)(CGPoint))moveHandler
                     tapHandler:(void (^)(void))tapHandler {
    if (self.running) return YES;

    void *bbs = dlopen("/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices", RTLD_LAZY);
    if (bbs == NULL) {
        AXHIDLog(@"dlopen BBS failed: %s", dlerror());
        return NO;
    }
    AXHIDRegisterFn reg = (AXHIDRegisterFn)dlsym(bbs, "BKSHIDEventRegisterEventCallback");
    sGetPoint = (AXHIDGetPointFn)dlsym(bbs, "BKSHIDEventGetHitTestPointFromDigitizerEventForPathEvent");
    sGetType = (AXIOHIDGetTypeFn)dlsym(RTLD_DEFAULT, "IOHIDEventGetType");
    if (reg == NULL || sGetPoint == NULL) {
        AXHIDLog(@"dlsym failed reg=%p getpoint=%p gettype=%p err=%s", reg, sGetPoint, sGetType, dlerror());
        return NO;
    }

    self.centerProvider = centerProvider;
    self.moveHandler = moveHandler;
    self.tapHandler = tapHandler;
    sManager = self;
    sDragging = NO;
    sDumpBudget = 12;

    reg((void *)axhid_callback);
    self.running = YES;
    AXHIDLog(@"started reg=%p getpoint=%p gettype=%p", reg, sGetPoint, sGetType);
    return YES;
}

- (void)stop {
    sManager = nil;
    self.running = NO;
    AXHIDLog(@"stopped");
}

@end
