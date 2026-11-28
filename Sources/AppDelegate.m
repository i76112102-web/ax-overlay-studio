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
    // 切到其它 App：保留红球（跨 App 悬浮核心需求），也保留 RemoteCall，
    // 这样杀掉 App 时还能用它把红球 setHidden。
    self.window.hidden = YES;
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    self.window.hidden = NO;
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // 上划杀掉 App：先移除红球，再安全销毁 RemoteCall。
    // 顺序不能反：RemoteCall 销毁后就没有通道隐藏 SpringBoard 里的窗口了。
    // 同时避免 trojan 线程返回 FAKE_LR_TROJAN(0x401) 打崩 SpringBoard → 锁屏。
    [[CrossAppOverlayController sharedController] removeCrossAppOverlayAndTeardown];
}

@end
