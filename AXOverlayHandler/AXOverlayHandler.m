#import "AXOverlayHandler.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <syslog.h>
#import <unistd.h>
#import <dispatch/dispatch.h>

static char kAXBallTargetKey;

__attribute__((constructor))
static void axh_constructor(void) {
    syslog(LOG_NOTICE, "[AXHDL] constructor pid=%d", getpid());
}

void AXHandlerProbe(uint64_t value) {
    syslog(LOG_NOTICE, "[AXHDL] probe value=0x%llx", (unsigned long long)value);
}

@interface AXBallPanTarget : NSObject
@property (nonatomic, weak) UIView *ball;
@end

@implementation AXBallPanTarget

- (void)handlePan:(UIPanGestureRecognizer *)gr {
    UIView *v = self.ball;
    if (!v) return;
    CGPoint t = [gr translationInView:nil];
    CGPoint c = v.center;
    c.x += t.x;
    c.y += t.y;
    v.center = c;
    [gr setTranslation:CGPointZero inView:nil];
    syslog(LOG_NOTICE, "[AXHDL] pan state=%ld center=(%.0f,%.0f)", (long)gr.state, c.x, c.y);
}

@end

void AXHandlerAttach(uint64_t winAddr) {
    // 所有 ObjC 调用派发到 SpringBoard 主线程；trojan 线程只做纯 C 的 dispatch_async。
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *win = (__bridge UIView *)(void *)(uintptr_t)winAddr;
        if (!win) {
            syslog(LOG_NOTICE, "[AXHDL] attach win=0");
            return;
        }
        AXBallPanTarget *target = [[AXBallPanTarget alloc] init];
        target.ball = win;
        objc_setAssociatedObject(win, &kAXBallTargetKey, target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:target action:@selector(handlePan:)];
        [win addGestureRecognizer:pan];
        win.userInteractionEnabled = YES;
        syslog(LOG_NOTICE, "[AXHDL] attach win=%p pan=%p target=%p", (__bridge void *)win, (__bridge void *)pan, (__bridge void *)target);
    });
    syslog(LOG_NOTICE, "[AXHDL] attach dispatched win=0x%llx", (unsigned long long)winAddr);
}
