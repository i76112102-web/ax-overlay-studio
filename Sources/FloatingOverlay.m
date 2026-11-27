#import "FloatingOverlay.h"
#import "Theme.h"

static NSString *const kFloatingOriginX = @"V2FloatingOriginX";
static NSString *const kFloatingOriginY = @"V2FloatingOriginY";
static CGFloat const kBallSide = 62.0;
static CGFloat const kMargin = 12.0;

@interface FloatingOverlay () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) FloatingBallView *ballView;
@property (nonatomic, assign) BOOL crossAppMode;
@end

@implementation FloatingOverlay

+ (instancetype)sharedOverlay {
    static dispatch_once_t onceToken;
    static FloatingOverlay *overlay = nil;
    dispatch_once(&onceToken, ^{
        overlay = [[FloatingOverlay alloc] init];
    });
    return overlay;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _crossAppMode = NO;
    }
    return self;
}

- (CGFloat)currentWindowLevel {
    return self.crossAppMode ? 10000000.0 : (UIWindowLevelAlert + 1000.0);
}

- (BOOL)isCrossAppMode {
    return self.crossAppMode;
}

- (CGPoint)initialOrigin {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    CGFloat x = [defaults floatForKey:kFloatingOriginX];
    CGFloat y = [defaults floatForKey:kFloatingOriginY];
    CGRect bounds = [UIScreen mainScreen].bounds;
    if (x <= 0 || y <= 0 || x + kBallSide > CGRectGetWidth(bounds) || y + kBallSide > CGRectGetHeight(bounds)) {
        x = CGRectGetWidth(bounds) - kBallSide - kMargin;
        y = CGRectGetHeight(bounds) * 0.38;
    }
    return CGPointMake(x, y);
}

- (void)persistOrigin:(CGPoint)origin {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setFloat:origin.x forKey:kFloatingOriginX];
    [defaults setFloat:origin.y forKey:kFloatingOriginY];
    [defaults synchronize];
}

- (void)buildIfNeeded {
    if (self.overlayWindow != nil) {
        self.overlayWindow.windowLevel = [self currentWindowLevel];
        return;
    }

    CGRect bounds = [UIScreen mainScreen].bounds;
    UIWindow *window = [[UIWindow alloc] initWithFrame:bounds];
    window.windowLevel = [self currentWindowLevel];
    window.backgroundColor = [UIColor clearColor];
    window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    UIViewController *root = [[UIViewController alloc] init];
    root.view.backgroundColor = [UIColor clearColor];
    window.rootViewController = root;

    FloatingBallView *ball = [[FloatingBallView alloc] initWithFrame:CGRectZero];
    ball.translatesAutoresizingMaskIntoConstraints = NO;
    CGPoint origin = [self initialOrigin];
    [root.view addSubview:ball];
    [NSLayoutConstraint activateConstraints:@[
        [ball.leadingAnchor constraintEqualToAnchor:root.view.leadingAnchor constant:origin.x],
        [ball.topAnchor constraintEqualToAnchor:root.view.topAnchor constant:origin.y],
        [ball.widthAnchor constraintEqualToConstant:kBallSide],
        [ball.heightAnchor constraintEqualToConstant:kBallSide]
    ]];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    pan.delegate = self;
    [ball addGestureRecognizer:pan];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    tap.delegate = self;
    [ball addGestureRecognizer:tap];

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                            action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.4;
    longPress.delegate = self;
    [ball addGestureRecognizer:longPress];

    __weak typeof(self) weakSelf = self;
    ball.menuItems = @[
        [[FloatingBallMenuItem alloc] initWithTitle:@"切换模式" action:^{
            [weakSelf setCrossAppMode:!weakSelf.crossAppMode];
        }],
        [[FloatingBallMenuItem alloc] initWithTitle:@"隐藏浮球" action:^{
            [weakSelf hide];
        }],
        [[FloatingBallMenuItem alloc] initWithTitle:@"复位位置" action:^{
            [weakSelf resetPosition];
        }]
    ];

    self.overlayWindow = window;
    self.ballView = ball;
}

- (void)resetPosition {
    CGRect bounds = self.overlayWindow.bounds;
    CGPoint origin = CGPointMake(CGRectGetWidth(bounds) - kBallSide - kMargin, CGRectGetHeight(bounds) * 0.38);
    for (NSLayoutConstraint *constraint in self.ballView.superview.constraints) {
        if (constraint.firstItem == self.ballView && constraint.firstAttribute == NSLayoutAttributeLeading) {
            constraint.constant = origin.x;
        }
        if (constraint.firstItem == self.ballView && constraint.firstAttribute == NSLayoutAttributeTop) {
            constraint.constant = origin.y;
        }
    }
    [self persistOrigin:origin];
    [self.overlayWindow layoutIfNeeded];
}

- (void)setCrossAppMode:(BOOL)enabled {
    _crossAppMode = enabled;
    if (self.overlayWindow != nil) {
        self.overlayWindow.windowLevel = [self currentWindowLevel];
    }
}

- (void)show {
    [self buildIfNeeded];
    self.overlayWindow.hidden = NO;
    [self.overlayWindow makeKeyAndVisible];
}

- (void)hide {
    self.overlayWindow.hidden = YES;
    [self.ballView setMenuExpanded:NO animated:YES];
}

- (BOOL)isVisible {
    return self.overlayWindow != nil && !self.overlayWindow.hidden;
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.overlayWindow];
    NSArray<NSLayoutConstraint *> *constraints = self.ballView.superview.constraints;
    NSLayoutConstraint *leading = nil;
    NSLayoutConstraint *top = nil;
    for (NSLayoutConstraint *constraint in constraints) {
        if (constraint.firstItem == self.ballView && constraint.firstAttribute == NSLayoutAttributeLeading) {
            leading = constraint;
        }
        if (constraint.firstItem == self.ballView && constraint.firstAttribute == NSLayoutAttributeTop) {
            top = constraint;
        }
    }
    if (leading == nil || top == nil) {
        return;
    }

    CGFloat x = leading.constant + translation.x;
    CGFloat y = top.constant + translation.y;
    CGRect bounds = self.overlayWindow.bounds;
    x = MIN(MAX(x, kMargin), CGRectGetWidth(bounds) - kBallSide - kMargin);
    y = MIN(MAX(y, kMargin), CGRectGetHeight(bounds) - kBallSide - kMargin);
    leading.constant = x;
    top.constant = y;
    [gesture setTranslation:CGPointZero inView:self.overlayWindow];
    [self.overlayWindow layoutIfNeeded];

    if (gesture.state == UIGestureRecognizerStateEnded) {
        [self persistOrigin:CGPointMake(x, y)];
    }
}

- (void)handleTap:(UIGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateEnded) {
        [self.ballView setMenuExpanded:!self.ballView.menuExpanded animated:YES];
        if (self.ballView.onTap) {
            self.ballView.onTap();
        }
    }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [self.ballView setMenuExpanded:YES animated:YES];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return NO;
}

@end
