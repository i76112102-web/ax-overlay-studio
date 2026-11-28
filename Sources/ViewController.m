#import "ViewController.h"
#import "Theme.h"
#import "GradientBackgroundView.h"
#import "FloatingOverlay.h"
#import "KernelBridge.h"
#import "CrossAppOverlayController.h"
#import "AXHIDTouchManager.h"
#import "darksword_api_shim.h"
#include <stdlib.h>
#include <string.h>

@interface ViewController ()
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *themeLabel;
@property (nonatomic, strong) UIButton *kernelInitButton;
@property (nonatomic, strong) UIButton *themeButton;
@property (nonatomic, strong) UIButton *localFloatButton;
@property (nonatomic, strong) UIButton *crossAppButton;
@property (nonatomic, strong) UIView *heroCard;
@property (nonatomic, strong) UIView *statusCard;
@property (nonatomic, strong) UIImageView *heroIcon;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIView *navCard;
@property (nonatomic, strong) UIView *toggleView;
@property (nonatomic, strong) UILabel *statusTitle;
@property (nonatomic, strong) UIView *dragPad;   // step19: 跨 App 球拖动垫
@end

@implementation ViewController

- (void)loadView {
    self.view = [[GradientBackgroundView alloc] initWithFrame:[UIScreen mainScreen].bounds];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"AX Overlay Studio";
    self.navigationController.navigationBar.hidden = YES;
    [self buildUI];
    [self applyTheme];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applyTheme)
                                                 name:@"AXThemeDidChangeNotification"
                                               object:nil];
    // 测试版自动触发：dvt launch --env AXAUTO=1 时，延迟自动执行 内核初始化 → 注入 SpringBoard。
    // 绕开 AXAccessibilityAudit.perform_press 对自定义 UIButton 不触发 TouchUpInside 的问题。
    const char *autoEnv = getenv("AXAUTO");
    if (autoEnv != NULL && strcmp(autoEnv, "1") == 0) {
        [self performSelector:@selector(autoSequence) withObject:nil afterDelay:2.0];
    }
}

- (void)autoSequence {
    [self setStatus:@"状态：AUTO 内核初始化中…"];
    [[KernelBridge sharedBridge] initializeKernelWithCompletion:^(BOOL success, NSString *message) {
        [self setStatus:[NSString stringWithFormat:@"状态：AUTO %@\n%@",
                         success ? @"内核就绪" : @"初始化失败", message ?: @""]];
        if (success) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [self crossAppAction];
            });
        }
    }];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)buildUI {
    UIView *heroCard = [[UIView alloc] init];
    heroCard.translatesAutoresizingMaskIntoConstraints = NO;
    [heroCard.layer setCornerRadius:30.0 * [Theme scale]];
    [self.view addSubview:heroCard];
    self.heroCard = heroCard;

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:38.0
                                                                                          weight:UIImageSymbolWeightBold];
    UIImage *glyph = [[UIImage systemImageNamed:@"cube.transparent" compatibleWithTraitCollection:nil]
                      imageWithConfiguration:config];
    UIImageView *heroIcon = [[UIImageView alloc] initWithImage:glyph];
    heroIcon.translatesAutoresizingMaskIntoConstraints = NO;
    heroIcon.userInteractionEnabled = YES;
    [heroIcon addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(themeAction)]];
    [heroCard addSubview:heroIcon];
    self.heroIcon = heroIcon;

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"AX Overlay Studio";
    title.font = [Theme fontHero];
    [title addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self
                                                                       action:@selector(themeAction)]];
    title.userInteractionEnabled = YES;
    [heroCard addSubview:title];
    self.titleLabel = title;

    UILabel *themeLabel = [[UILabel alloc] init];
    themeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    themeLabel.font = [Theme fontFootnote];
    [themeLabel addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self
                                                                            action:@selector(themeAction)]];
    themeLabel.userInteractionEnabled = YES;
    [heroCard addSubview:themeLabel];
    self.themeLabel = themeLabel;

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.numberOfLines = 0;
    subtitle.font = [Theme fontLabel];
    subtitle.text = @"玻璃拟态界面 · DarkSword 内核底座 · 本机浮窗 / SpringBoard 跨 App 悬浮双模式";
    [heroCard addSubview:subtitle];
    self.subtitleLabel = subtitle;

    UIView *navCard = [Theme navigationCardWithTitle:@"跨 App 悬浮" subtitle:@"SpringBoard overlay" index:1];
    navCard.translatesAutoresizingMaskIntoConstraints = NO;
    [heroCard addSubview:navCard];
    self.navCard = navCard;

    UIView *toggle = [Theme toggleViewOn:YES];
    toggle.translatesAutoresizingMaskIntoConstraints = NO;
    [heroCard addSubview:toggle];
    self.toggleView = toggle;

    UIView *statusCard = [[UIView alloc] init];
    statusCard.translatesAutoresizingMaskIntoConstraints = NO;
    [statusCard.layer setCornerRadius:22.0 * [Theme scale]];
    [self.view addSubview:statusCard];
    self.statusCard = statusCard;

    UILabel *statusTitle = [[UILabel alloc] init];
    statusTitle.translatesAutoresizingMaskIntoConstraints = NO;
    statusTitle.text = @"运行状态";
    statusTitle.font = [Theme fontFootnote];
    [statusCard addSubview:statusTitle];
    self.statusTitle = statusTitle;

    UILabel *statusLabel = [[UILabel alloc] init];
    statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    statusLabel.numberOfLines = 0;
    statusLabel.font = [Theme fontLabel];
    statusLabel.text = @"状态：等待操作";
    [statusCard addSubview:statusLabel];
    self.statusLabel = statusLabel;

    UIButton *themeButton = [Theme visionButtonWithTitle:@"切换主题（7 套）"];
    [themeButton addTarget:self action:@selector(themeAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:themeButton];
    self.themeButton = themeButton;

    UIButton *kernelInitButton = [Theme visionButtonWithTitle:@"初始化内核"];
    [kernelInitButton addTarget:self action:@selector(kernelInitAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:kernelInitButton];
    self.kernelInitButton = kernelInitButton;

    UIButton *localButton = [Theme visionButtonWithTitle:@"显示本机悬浮图标"];
    [localButton addTarget:self action:@selector(localFloatAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:localButton];
    self.localFloatButton = localButton;

    UIButton *crossButton = [Theme visionButtonWithTitle:@"注入 SpringBoard 跨 App 悬浮"];
    [crossButton addTarget:self action:@selector(crossAppAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:crossButton];
    self.crossAppButton = crossButton;

    // step19: 跨 App 球拖动垫 —— pan 手势通过 kcall 实时移动 SpringBoard 里的悬浮球。
    UIView *dragPad = [[UIView alloc] init];
    dragPad.translatesAutoresizingMaskIntoConstraints = NO;
    dragPad.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.18];
    dragPad.layer.cornerRadius = 18.0;
    dragPad.userInteractionEnabled = YES;
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(handleDragPad:)];
    [dragPad addGestureRecognizer:pan];
    UILabel *dragHint = [[UILabel alloc] init];
    dragHint.translatesAutoresizingMaskIntoConstraints = NO;
    dragHint.text = @"↔ 拖动这里移动跨 App 悬浮球";
    dragHint.font = [Theme fontFootnote];
    dragHint.textColor = [Theme ink];
    dragHint.textAlignment = NSTextAlignmentCenter;
    [dragPad addSubview:dragHint];
    [NSLayoutConstraint activateConstraints:@[
        [dragHint.centerXAnchor constraintEqualToAnchor:dragPad.centerXAnchor],
        [dragHint.centerYAnchor constraintEqualToAnchor:dragPad.centerYAnchor],
        [dragHint.leadingAnchor constraintEqualToAnchor:dragPad.leadingAnchor constant:8],
        [dragHint.trailingAnchor constraintEqualToAnchor:dragPad.trailingAnchor constant:-8]
    ]];
    [self.view addSubview:dragPad];
    self.dragPad = dragPad;

    UILayoutGuide *guide = self.view.safeAreaLayoutGuide;
    CGFloat pad = AXLayoutCompactPad * [Theme scale];
    [NSLayoutConstraint activateConstraints:@[
        [heroCard.topAnchor constraintEqualToAnchor:guide.topAnchor constant:pad * 2],
        [heroCard.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:pad * 2],
        [heroCard.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor constant:-pad * 2],

        [heroIcon.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:pad * 2],
        [heroIcon.topAnchor constraintEqualToAnchor:heroCard.topAnchor constant:pad * 2],
        [heroIcon.widthAnchor constraintEqualToConstant:44.0 * [Theme scale]],
        [heroIcon.heightAnchor constraintEqualToConstant:44.0 * [Theme scale]],

        [title.topAnchor constraintEqualToAnchor:heroIcon.bottomAnchor constant:pad],
        [title.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:pad * 2],
        [title.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor constant:-pad * 2],

        [themeLabel.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:4.0],
        [themeLabel.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [themeLabel.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],

        [subtitle.topAnchor constraintEqualToAnchor:themeLabel.bottomAnchor constant:pad],
        [subtitle.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:pad * 2],
        [subtitle.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor constant:-pad * 2],

        [navCard.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:pad],
        [navCard.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:pad * 2],
        [navCard.widthAnchor constraintEqualToConstant:[Theme navCardWidth]],
        [navCard.heightAnchor constraintEqualToConstant:[Theme navCardHeight]],

        [toggle.centerYAnchor constraintEqualToAnchor:navCard.centerYAnchor],
        [toggle.leadingAnchor constraintEqualToAnchor:navCard.trailingAnchor constant:pad],
        [toggle.widthAnchor constraintEqualToConstant:[Theme toggleWidth]],
        [toggle.heightAnchor constraintEqualToConstant:[Theme toggleHeight]],
        [toggle.trailingAnchor constraintLessThanOrEqualToAnchor:heroCard.trailingAnchor constant:-pad * 2],
        [navCard.bottomAnchor constraintEqualToAnchor:heroCard.bottomAnchor constant:-pad * 2],

        [statusCard.topAnchor constraintEqualToAnchor:heroCard.bottomAnchor constant:pad],
        [statusCard.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor],
        [statusCard.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor],

        [statusTitle.topAnchor constraintEqualToAnchor:statusCard.topAnchor constant:pad * 1.5],
        [statusTitle.leadingAnchor constraintEqualToAnchor:statusCard.leadingAnchor constant:pad * 1.5],
        [statusTitle.trailingAnchor constraintEqualToAnchor:statusCard.trailingAnchor constant:-pad * 1.5],

        [statusLabel.topAnchor constraintEqualToAnchor:statusTitle.bottomAnchor constant:pad * 0.6],
        [statusLabel.leadingAnchor constraintEqualToAnchor:statusTitle.leadingAnchor],
        [statusLabel.trailingAnchor constraintEqualToAnchor:statusTitle.trailingAnchor],
        [statusLabel.bottomAnchor constraintEqualToAnchor:statusCard.bottomAnchor constant:-pad * 1.5],

        [themeButton.topAnchor constraintEqualToAnchor:statusCard.bottomAnchor constant:pad * 2],
        [themeButton.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor],
        [themeButton.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor],
        [themeButton.heightAnchor constraintEqualToConstant:44.0 * [Theme scale]],

        [kernelInitButton.topAnchor constraintEqualToAnchor:themeButton.bottomAnchor constant:pad],
        [kernelInitButton.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor],
        [kernelInitButton.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor],
        [kernelInitButton.heightAnchor constraintEqualToConstant:44.0 * [Theme scale]],

        [localButton.topAnchor constraintEqualToAnchor:kernelInitButton.bottomAnchor constant:pad],
        [localButton.leadingAnchor constraintEqualToAnchor:kernelInitButton.leadingAnchor],
        [localButton.trailingAnchor constraintEqualToAnchor:kernelInitButton.trailingAnchor],
        [localButton.heightAnchor constraintEqualToAnchor:kernelInitButton.heightAnchor],

        [crossButton.topAnchor constraintEqualToAnchor:localButton.bottomAnchor constant:pad],
        [crossButton.leadingAnchor constraintEqualToAnchor:kernelInitButton.leadingAnchor],
        [crossButton.trailingAnchor constraintEqualToAnchor:kernelInitButton.trailingAnchor],
        [crossButton.heightAnchor constraintEqualToAnchor:kernelInitButton.heightAnchor],

        // step19: 拖动垫放在最后一个按钮下方。
        [self.dragPad.topAnchor constraintEqualToAnchor:crossButton.bottomAnchor constant:pad],
        [self.dragPad.leadingAnchor constraintEqualToAnchor:kernelInitButton.leadingAnchor],
        [self.dragPad.trailingAnchor constraintEqualToAnchor:kernelInitButton.trailingAnchor],
        [self.dragPad.heightAnchor constraintEqualToConstant:52.0 * [Theme scale]]
    ]];
}

- (void)applyTheme {
    AXThemePalette p = [Theme sharedTheme].material;
    self.view.backgroundColor = AXUIColor(p.field);
    self.titleLabel.textColor = [Theme ink];
    self.subtitleLabel.textColor = [Theme muted];
    self.themeLabel.textColor = [Theme muted];
    self.themeLabel.text = [NSString stringWithFormat:@"主题 %lu/7 · 点击标题或按钮切换",
                            (unsigned long)([Theme sharedTheme].paletteIndex + 1)];
    self.statusTitle.textColor = [Theme muted];
    self.statusLabel.textColor = [Theme ink];
    self.heroIcon.tintColor = [Theme accent];

    // 按报告尺寸重建 Navigation 卡（208×64*s）与 Toggle（44×24*s）。
    UIView *oldNav = self.navCard;
    UIView *newNav = [Theme navigationCardWithTitle:@"跨 App 悬浮" subtitle:@"SpringBoard overlay" index:1];
    newNav.translatesAutoresizingMaskIntoConstraints = NO;
    [self.heroCard insertSubview:newNav aboveSubview:oldNav];
    [NSLayoutConstraint activateConstraints:@[
        [newNav.topAnchor constraintEqualToAnchor:oldNav.topAnchor],
        [newNav.leadingAnchor constraintEqualToAnchor:oldNav.leadingAnchor],
        [newNav.widthAnchor constraintEqualToConstant:[Theme navCardWidth]],
        [newNav.heightAnchor constraintEqualToConstant:[Theme navCardHeight]]
    ]];
    [oldNav removeFromSuperview];
    self.navCard = newNav;

    UIView *oldToggle = self.toggleView;
    UIView *newToggle = [Theme toggleViewOn:YES];
    newToggle.translatesAutoresizingMaskIntoConstraints = NO;
    [self.heroCard insertSubview:newToggle aboveSubview:oldToggle];
    [NSLayoutConstraint activateConstraints:@[
        [newToggle.centerYAnchor constraintEqualToAnchor:newNav.centerYAnchor],
        [newToggle.leadingAnchor constraintEqualToAnchor:newNav.trailingAnchor constant:AXLayoutCompactPad * [Theme scale]],
        [newToggle.widthAnchor constraintEqualToConstant:[Theme toggleWidth]],
        [newToggle.heightAnchor constraintEqualToConstant:[Theme toggleHeight]]
    ]];
    [oldToggle removeFromSuperview];
    self.toggleView = newToggle;

    [self applyShell:self.heroCard palette:p radius:30.0 * [Theme scale]];
    [self applyShell:self.statusCard palette:p radius:22.0 * [Theme scale]];
    NSArray<UIButton *> *buttons = @[self.themeButton, self.kernelInitButton, self.localFloatButton, self.crossAppButton];
    for (UIButton *button in buttons) {
        NSMutableArray<CALayer *> *remove = [NSMutableArray array];
        for (CALayer *layer in button.layer.sublayers) {
            if ([layer isKindOfClass:[CAGradientLayer class]] || [layer isKindOfClass:[CAShapeLayer class]]) {
                [remove addObject:layer];
            }
        }
        for (CALayer *layer in remove) {
            [layer removeFromSuperlayer];
        }
        [Theme applyLiquidBodyToView:button palette:p radius:[Theme buttonRadius] opacity:1.0];
        [Theme applyLiquidEdgesToView:button palette:p radius:[Theme buttonRadius] emphasis:0.0];
        [button.titleLabel setFont:[Theme fontBody]];
        [button setTitleColor:[Theme ink] forState:UIControlStateNormal];
        [button setTitleColor:[Theme onAccent] forState:UIControlStateHighlighted];
    }
}

- (void)applyShell:(UIView *)view palette:(AXThemePalette)p radius:(CGFloat)radius {
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:[UIVisualEffectView class]]) {
            [sub removeFromSuperview];
        }
    }
    NSMutableArray<CALayer *> *remove = [NSMutableArray array];
    for (CALayer *layer in view.layer.sublayers) {
        if ([layer isKindOfClass:[CAGradientLayer class]] || [layer isKindOfClass:[CAShapeLayer class]]) {
            [remove addObject:layer];
        }
    }
    for (CALayer *layer in remove) {
        [layer removeFromSuperlayer];
    }
    [Theme applyShellToView:view palette:p radius:radius scale:[Theme scale] alpha:1.0];
}

// 标题、Emblem 图标或专用按钮均循环 7 套主题。
- (void)themeAction {
    [[Theme sharedTheme] advancePalette];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AXThemeDidChangeNotification" object:nil];
}

- (void)setStatus:(NSString *)text {
    self.statusLabel.text = text;
}

- (void)kernelInitAction {
    [self setStatus:@"状态：内核初始化中…"];
    [[KernelBridge sharedBridge] initializeKernelWithCompletion:^(BOOL success, NSString *message) {
        [self setStatus:[NSString stringWithFormat:@"状态：%@\n%@", success ? @"内核就绪" : @"初始化失败", message ?: @""]];
    }];
}

- (void)localFloatAction {
    FloatingOverlay *overlay = [FloatingOverlay sharedOverlay];
    [overlay setCrossAppMode:NO];
    if ([overlay isVisible]) {
        [overlay hide];
        [self setStatus:@"状态：本机悬浮图标已隐藏"];
    } else {
        [overlay show];
        [self setStatus:[NSString stringWithFormat:@"状态：本机悬浮图标已显示\nwindowLevel=%.1f，仅本进程可见",
                         [overlay currentWindowLevel]]];
    }
    [self.localFloatButton setTitle:[overlay isVisible] ? @"隐藏本机悬浮图标" : @"显示本机悬浮图标"
                           forState:UIControlStateNormal];
}

- (void)crossAppAction {
    [self setStatus:@"状态：准备注入 SpringBoard…"];
    CrossAppOverlayController *controller = [CrossAppOverlayController sharedController];
    NSError *error = nil;
    BOOL ok = [controller installCrossAppOverlayWithWindowLevel:10000000.0 error:&error];
    if (!ok) {
        [self setStatus:[NSString stringWithFormat:@"状态：跨 App 注入未执行\n%@",
                         error.localizedDescription ?: @"未知错误"]];
        return;
    }
    // 跨 App 视图已在 SpringBoard 进程内创建（remoteBubbleView），不需要再显示本进程浮窗。
    [self setStatus:@"状态：跨 App 悬浮已提交到 SpringBoard\n切到任意 App 核对；syslog 看 SpringBoard[pid] 窗口打印"];

    // step26: 参考 AX 的 BKSHIDEventRegisterEventCallback 全局触摸链，
    // 在本进程注册 HID 回调拿全局坐标，命中红球后通过已验证的 NSInvocation setFrame 路径移动。
    AXHIDTouchManager *hid = [AXHIDTouchManager sharedManager];
    [hid startWithCenterProvider:^CGPoint(void) {
        return [[CrossAppOverlayController sharedController] currentOverlayCenter];
    } moveHandler:^(CGPoint point) {
        NSError *moveError = nil;
        [[CrossAppOverlayController sharedController] moveOverlayToPoint:point error:&moveError];
        if (moveError) {
            NSLog(@"[AXHID] move failed: %@", moveError.localizedDescription);
        }
    } tapHandler:^{
        NSLog(@"[AXHID] tap ball");
    }];

    // step19 测试钩子：AXDRAG=1 时延迟模拟一次拖动，验证 kcall moveOverlayToPoint 生效。
    const char *dragEnv = getenv("AXDRAG");
    if (dragEnv != NULL && strcmp(dragEnv, "1") == 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            NSError *moveError = nil;
            CGPoint target = CGPointMake(90.0, 720.0);
            BOOL moved = [[CrossAppOverlayController sharedController] moveOverlayToPoint:target
                                                                                   error:&moveError];
            [self setStatus:[NSString stringWithFormat:@"状态：拖动测试 %@\n目标 (%.0f, %.0f) %@",
                             moved ? @"OK" : @"FAIL", target.x, target.y,
                             moveError.localizedDescription ?: @""]];
        });
    }
}

// step19: 拖动垫 pan → kcall 实时移动 SpringBoard 悬浮球。
// 球的 frame 更新在 SpringBoard 主线程执行；这里只传目标圆心坐标。
- (void)handleDragPad:(UIPanGestureRecognizer *)gesture {
    CrossAppOverlayController *controller = [CrossAppOverlayController sharedController];
    CGPoint translation = [gesture translationInView:self.view];
    CGPoint center = [controller currentOverlayCenter];
    center.x += translation.x;
    center.y += translation.y;
    [gesture setTranslation:CGPointZero inView:self.view];

    NSError *error = nil;
    BOOL ok = [controller moveOverlayToPoint:center error:&error];
    if (gesture.state == UIGestureRecognizerStateEnded) {
        [self setStatus:[NSString stringWithFormat:@"状态：跨 App 球已移动到 (%.0f, %.0f)\n%@",
                         center.x, center.y, ok ? @"位置更新成功" : (error.localizedDescription ?: @"更新失败")]];
    }
}

@end
