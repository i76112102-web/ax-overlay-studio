#import "ViewController.h"
#import "Theme.h"
#import "GradientBackgroundView.h"
#import "FloatingOverlay.h"
#import "KernelBridge.h"
#import "CrossAppOverlayController.h"
#import "darksword_api_shim.h"

@interface ViewController ()
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *themeLabel;
@property (nonatomic, strong) UIButton *initButton;
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

    UIButton *initButton = [Theme visionButtonWithTitle:@"初始化内核"];
    [initButton addTarget:self action:@selector(initAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:initButton];
    self.initButton = initButton;

    UIButton *localButton = [Theme visionButtonWithTitle:@"显示本机悬浮图标"];
    [localButton addTarget:self action:@selector(localFloatAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:localButton];
    self.localFloatButton = localButton;

    UIButton *crossButton = [Theme visionButtonWithTitle:@"注入 SpringBoard 跨 App 悬浮"];
    [crossButton addTarget:self action:@selector(crossAppAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:crossButton];
    self.crossAppButton = crossButton;

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

        [initButton.topAnchor constraintEqualToAnchor:themeButton.bottomAnchor constant:pad],
        [initButton.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor],
        [initButton.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor],
        [initButton.heightAnchor constraintEqualToConstant:44.0 * [Theme scale]],

        [localButton.topAnchor constraintEqualToAnchor:initButton.bottomAnchor constant:pad],
        [localButton.leadingAnchor constraintEqualToAnchor:initButton.leadingAnchor],
        [localButton.trailingAnchor constraintEqualToAnchor:initButton.trailingAnchor],
        [localButton.heightAnchor constraintEqualToAnchor:initButton.heightAnchor],

        [crossButton.topAnchor constraintEqualToAnchor:localButton.bottomAnchor constant:pad],
        [crossButton.leadingAnchor constraintEqualToAnchor:initButton.leadingAnchor],
        [crossButton.trailingAnchor constraintEqualToAnchor:initButton.trailingAnchor],
        [crossButton.heightAnchor constraintEqualToAnchor:initButton.heightAnchor]
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
    NSArray<UIButton *> *buttons = @[self.themeButton, self.initButton, self.localFloatButton, self.crossAppButton];
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

- (void)initAction {
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
    [[FloatingOverlay sharedOverlay] setCrossAppMode:YES];
    [[FloatingOverlay sharedOverlay] show];
    [self setStatus:@"状态：跨 App 序列已提交\n用 syslog 核对 SBWindowManager / windowLevel 打印者"];
}

@end
