#import "AppDelegate.h"
#import "ViewController.h"
#import "CrossAppOverlayController.h"
#import <UIKit/UIKit.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // 防止自动化验证期间系统空闲定时器锁屏（idleTimerDidExpire）。
    // 前台期间保持唤醒；红球由 SpringBoard 承载，切到其它 App 后不受本 App 影响。
    application.idleTimerDisabled = YES;
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    ViewController *root = [[ViewController alloc] init];
    self.window.rootViewController = root;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // 铁证：SpringBoard-2026-11-28-033325.ips 触发线程 pc=0x401 lr=0x401
    // = RemoteCall.h FAKE_LR_TROJAN。RemoteCall 的异常驱动 trojan/creator 线程
    // 依赖本进程异常处理；App 退后台被挂起后异常无人应答，线程跳 0x401 打崩 SpringBoard → 锁屏。
    // 必须在仍前台（active→inactive，本进程异常处理器可用）时提前 destroy，
    // 让 trojan 线程经 pthread_exit 安全退出。红球 UIWindow 由 SpringBoard 持有，显示不受影响。
    [[CrossAppOverlayController sharedController] teardownRemoteCall];
    self.window.hidden = YES;
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    self.window.hidden = NO;
}

@end
