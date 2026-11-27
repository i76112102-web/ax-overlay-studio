#import "FloatingBallView.h"
#import "Theme.h"

static CGFloat const kBallSize = 62.0;
static CGFloat const kMenuItemHeight = 42.0;
static CGFloat const kMenuGap = 8.0;

@interface FloatingBallMenuItem ()
@property (nonatomic, copy, readwrite) NSString *title;
@property (nonatomic, copy, readwrite) void (^action)(void);
@end

@implementation FloatingBallMenuItem

- (instancetype)initWithTitle:(NSString *)title action:(void (^)(void))action {
    self = [super init];
    if (self) {
        _title = [title copy];
        _action = [action copy];
    }
    return self;
}

@end

@interface FloatingBallView ()
@property (nonatomic, strong) UIView *ballView;
@property (nonatomic, strong) UIImageView *glyphView;
@property (nonatomic, strong) UIView *menuContainer;
@property (nonatomic, strong) NSArray<UIButton *> *menuButtons;
@property (nonatomic, strong) UILabel *hintLabel;
@end

@implementation FloatingBallView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = YES;
        _menuExpanded = NO;
        [self buildSubviews];
        [self applyTheme];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applyTheme)
                                                     name:@"AXThemeDidChangeNotification"
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)buildSubviews {
    UIView *menu = [[UIView alloc] initWithFrame:CGRectZero];
    menu.translatesAutoresizingMaskIntoConstraints = NO;
    menu.backgroundColor = [UIColor clearColor];
    menu.hidden = YES;
    [self addSubview:menu];
    self.menuContainer = menu;

    UIView *ball = [[UIView alloc] initWithFrame:CGRectZero];
    ball.translatesAutoresizingMaskIntoConstraints = NO;
    ball.layer.cornerRadius = kBallSize / 2.0;
    ball.layer.masksToBounds = YES;
    [self addSubview:ball];
    self.ballView = ball;

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:24.0
                                                                                          weight:UIImageSymbolWeightSemibold];
    UIImage *glyph = [UIImage systemImageNamed:@"sparkles" compatibleWithTraitCollection:nil];
    UIImageView *glyphView = [[UIImageView alloc] initWithImage:[glyph imageWithConfiguration:config]];
    glyphView.translatesAutoresizingMaskIntoConstraints = NO;
    glyphView.userInteractionEnabled = NO;
    [ball addSubview:glyphView];
    self.glyphView = glyphView;

    UILabel *hint = [[UILabel alloc] init];
    hint.translatesAutoresizingMaskIntoConstraints = NO;
    hint.font = [Theme fontFootnote];
    hint.textAlignment = NSTextAlignmentCenter;
    hint.text = @"拖动 / 点击";
    [self addSubview:hint];
    self.hintLabel = hint;

    [NSLayoutConstraint activateConstraints:@[
        [ball.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [ball.topAnchor constraintEqualToAnchor:self.topAnchor],
        [ball.widthAnchor constraintEqualToConstant:kBallSize],
        [ball.heightAnchor constraintEqualToConstant:kBallSize],
        [glyphView.centerXAnchor constraintEqualToAnchor:ball.centerXAnchor],
        [glyphView.centerYAnchor constraintEqualToAnchor:ball.centerYAnchor],
        [hint.topAnchor constraintEqualToAnchor:ball.bottomAnchor constant:4.0],
        [hint.centerXAnchor constraintEqualToAnchor:ball.centerXAnchor],
        [hint.widthAnchor constraintEqualToConstant:80.0],
        [menu.trailingAnchor constraintEqualToAnchor:ball.trailingAnchor],
        [menu.bottomAnchor constraintEqualToAnchor:ball.topAnchor constant:-kMenuGap],
        [menu.widthAnchor constraintEqualToConstant:130.0],
        [menu.heightAnchor constraintEqualToConstant:(kMenuItemHeight + kMenuGap) * 3.0 - kMenuGap]
    ]];
}

- (void)applyTheme {
    AXThemePalette p = [Theme sharedTheme].material;
    [Theme applyLiquidBodyToView:self.ballView palette:p radius:kBallSize / 2.0 opacity:1.0];
    self.glyphView.tintColor = [Theme accent];
    self.hintLabel.textColor = [Theme muted];
}

- (void)setMenuItems:(NSArray<FloatingBallMenuItem *> *)menuItems {
    _menuItems = [menuItems copy];
    [self rebuildMenuItems];
}

- (void)rebuildMenuItems {
    for (UIView *view in self.menuContainer.subviews) {
        [view removeFromSuperview];
    }

    __weak typeof(self) weakSelf = self;
    NSMutableArray<UIButton *> *buttons = [NSMutableArray array];
    [self.menuItems enumerateObjectsUsingBlock:^(FloatingBallMenuItem *item, NSUInteger idx, BOOL *stop) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        [button setTitle:item.title forState:UIControlStateNormal];
        [button setTitleColor:[Theme ink] forState:UIControlStateNormal];
        button.titleLabel.font = [Theme fontLabel];
        button.layer.cornerRadius = 12.0;
        button.tag = (NSInteger)idx;
        [button addTarget:weakSelf
                   action:@selector(menuItemTapped:)
         forControlEvents:UIControlEventTouchUpInside];
        [weakSelf.menuContainer addSubview:button];
        [buttons addObject:button];

        CGFloat bottomOffset = (CGFloat)(weakSelf.menuItems.count - idx - 1) * (kMenuItemHeight + kMenuGap);
        [NSLayoutConstraint activateConstraints:@[
            [button.leadingAnchor constraintEqualToAnchor:weakSelf.menuContainer.leadingAnchor],
            [button.trailingAnchor constraintEqualToAnchor:weakSelf.menuContainer.trailingAnchor],
            [button.bottomAnchor constraintEqualToAnchor:weakSelf.menuContainer.bottomAnchor constant:-bottomOffset],
            [button.heightAnchor constraintEqualToConstant:kMenuItemHeight]
        ]];
    }];
    self.menuButtons = buttons;
    [self applyMenuTheme];
}

- (void)applyMenuTheme {
    AXThemePalette p = [Theme sharedTheme].material;
    for (UIButton *button in self.menuButtons) {
        [Theme applyLiquidBodyToView:button palette:p radius:12.0 opacity:1.0];
        [Theme applyLiquidEdgesToView:button palette:p radius:12.0 emphasis:0.0];
    }
}

- (void)menuItemTapped:(UIButton *)sender {
    if (sender.tag < (NSInteger)self.menuItems.count) {
        FloatingBallMenuItem *item = self.menuItems[sender.tag];
        if (item.action) {
            item.action();
        }
    }
    [self setMenuExpanded:NO animated:YES];
}

- (void)setMenuExpanded:(BOOL)menuExpanded {
    [self setMenuExpanded:menuExpanded animated:NO];
}

- (void)setMenuExpanded:(BOOL)menuExpanded animated:(BOOL)animated {
    _menuExpanded = menuExpanded;
    // reduceMotion 全链路短路：Ease 直接赋值，intro=1，pulse=0.5。
    if (animated && !AXReduceMotion()) {
        if (menuExpanded) {
            self.menuContainer.hidden = NO;
            self.menuContainer.alpha = 0.0;
            self.menuContainer.transform = CGAffineTransformMakeScale(0.86, 0.86);
            [UIView animateWithDuration:0.18 delay:0.0 usingSpringWithDamping:0.75 initialSpringVelocity:0.6
                                options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.menuContainer.alpha = 1.0;
                self.menuContainer.transform = CGAffineTransformIdentity;
            } completion:nil];
        } else {
            [UIView animateWithDuration:0.14 animations:^{
                self.menuContainer.alpha = 0.0;
                self.menuContainer.transform = CGAffineTransformMakeScale(0.9, 0.9);
            } completion:^(BOOL finished) {
                self.menuContainer.hidden = YES;
                self.menuContainer.transform = CGAffineTransformIdentity;
            }];
        }
    } else {
        self.menuContainer.hidden = !menuExpanded;
        self.menuContainer.alpha = menuExpanded ? 1.0 : 0.0;
        self.menuContainer.transform = CGAffineTransformIdentity;
    }
}

@end
