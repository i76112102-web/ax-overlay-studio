#import "AppDelegate.h"
#import "ViewController.h"
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

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // RemoteCall 的 trojan 线程在 SpringBoard 内是异常驱动的一次性线程；
    // 宿主 App 退后台后线程状态会失稳，最终跳到 0x401（FAKE_LR_TROJAN）打崩 SpringBoard。
    // 这里在退后台瞬间只隐藏窗口、不销毁 RemoteCall，避免 trojan 返回路径触发。
    self.window.hidden = YES;
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    self.window.hidden = NO;
}

@end
