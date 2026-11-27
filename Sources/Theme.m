#import "Theme.h"
#import <objc/runtime.h>

CGFloat const AXLayoutWideW    = 1120.0;
CGFloat const AXLayoutWideH    = 720.0;
CGFloat const AXLayoutWidePad  = 24.0;
CGFloat const AXLayoutCompactW = 384.0;
CGFloat const AXLayoutCompactPad = 12.0;

static NSString *const AXThemeIndexKey = @"AXThemePaletteIndex_v2";

static AXColor4 AXMix(AXColor4 a, AXColor4 b, CGFloat t) {
    t = MAX(0.0, MIN(1.0, t));
    return (AXColor4){
        a.r + (b.r - a.r) * t,
        a.g + (b.g - a.g) * t,
        a.b + (b.b - a.b) * t,
        a.a + (b.a - a.a) * t
    };
}

AXColor4 AXOpacity(AXColor4 c, CGFloat a) {
    c.a = a;
    return c;
}

AXThemePalette AXThemeGet(NSUInteger index) {
    // 数值逐字来自 SpatialTheme.h::Get()，顺序：
    // shell, sidebar, surface, field, hover, active, ink, muted, accent, onAccent, border, hero, heroInk
    static AXThemePalette palettes[AXThemeCount] = {
        { "瓷白", "主页原色", YES,
          AXRGBA(239,243,247,248), AXRGBA(245,249,253,245),
          AXRGBA(235,243,251,238), AXRGBA(229,232,237,238),
          AXRGBA(213,220,228,245), AXRGBA(191,202,214,250),
          AXRGBA(39,42,46,255), AXRGBA(101,111,122,255),
          AXRGBA(40,42,46,255), AXRGBA(255,255,255,255),
          AXRGBA(255,255,255,155), AXRGBA(28,37,48,255), AXRGBA(255,255,255,255) },
        { "雾透", "通透玻璃", YES,
          AXRGBA(249,250,252,144), AXRGBA(249,250,252,36),
          AXRGBA(249,250,252,34), AXRGBA(246,249,252,72),
          AXRGBA(255,255,255,112), AXRGBA(231,238,245,150),
          AXRGBA(29,37,45,255), AXRGBA(47,62,75,255),
          AXRGBA(60,80,99,255), AXRGBA(255,255,255,255),
          AXRGBA(255,255,255,104), AXRGBA(224,235,245,174), AXRGBA(29,37,45,255) },
        { "石墨", "沉静深色", NO,
          AXRGBA(23,27,34,236), AXRGBA(31,37,47,104),
          AXRGBA(42,49,61,88), AXRGBA(11,15,22,126),
          AXRGBA(114,128,148,76), AXRGBA(140,156,178,104),
          AXRGBA(240,243,248,255), AXRGBA(174,185,201,255),
          AXRGBA(216,225,238,255), AXRGBA(26,34,46,255),
          AXRGBA(226,234,247,56), AXRGBA(13,18,26,218), AXRGBA(240,243,248,255) },
        { "海湾", "清澈蓝调", NO,
          AXRGBA(20,45,66,222), AXRGBA(27,60,83,96),
          AXRGBA(43,83,108,76), AXRGBA(8,29,46,128),
          AXRGBA(107,182,220,68), AXRGBA(120,207,255,92),
          AXRGBA(236,247,255,255), AXRGBA(170,201,222,255),
          AXRGBA(120,207,255,255), AXRGBA(9,43,67,255),
          AXRGBA(169,220,250,66), AXRGBA(10,31,49,202), AXRGBA(236,247,255,255) },
        { "松林", "柔和绿意", NO,
          AXRGBA(24,46,40,226), AXRGBA(33,64,54,96),
          AXRGBA(47,82,68,76), AXRGBA(10,30,24,128),
          AXRGBA(125,191,163,68), AXRGBA(147,222,193,92),
          AXRGBA(238,249,242,255), AXRGBA(176,207,190,255),
          AXRGBA(147,222,193,255), AXRGBA(12,47,37,255),
          AXRGBA(185,232,207,64), AXRGBA(13,33,27,204), AXRGBA(238,249,242,255) },
        { "鸢尾", "低饱和紫", NO,
          AXRGBA(40,33,57,226), AXRGBA(56,47,77,98),
          AXRGBA(75,62,101,76), AXRGBA(25,18,40,128),
          AXRGBA(167,144,212,68), AXRGBA(197,176,255,92),
          AXRGBA(247,242,255,255), AXRGBA(198,186,218,255),
          AXRGBA(197,176,255,255), AXRGBA(43,25,73,255),
          AXRGBA(222,206,252,64), AXRGBA(27,20,42,204), AXRGBA(247,242,255,255) },
        { "暖砂", "温润米色", YES,
          AXRGBA(240,228,211,236), AXRGBA(250,240,225,126),
          AXRGBA(255,248,237,108), AXRGBA(215,197,173,128),
          AXRGBA(201,178,149,150), AXRGBA(182,153,120,168),
          AXRGBA(61,48,36,255), AXRGBA(113,89,65,255),
          AXRGBA(126,89,55,255), AXRGBA(255,250,243,255),
          AXRGBA(255,250,240,154), AXRGBA(102,74,49,230), AXRGBA(255,248,237,255) }
    };
    NSUInteger i = index >= AXThemeCount ? AXThemeCount - 1 : index;
    return palettes[i];
}

AXThemePalette AXMaterialFromPalette(AXThemePalette p) {
    // surface 与 (0.94,0.97,1.0) 混合：light 0.18 / dark 0.70。
    AXColor4 pale = (AXColor4){0.94, 0.97, 1.0, 1.0};
    p.surface = AXMix(p.surface, pale, p.light ? 0.18 : 0.70);
    p.surface.a = p.light ? 0.16 : 0.12;
    p.shell   = p.surface; p.shell.a   = p.light ? 0.12 : 0.08;
    p.sidebar = p.surface;
    p.field   = p.surface;
    p.hover   = p.surface; p.hover.a   = p.light ? 0.21 : 0.17;
    p.active  = p.surface; p.active.a  = p.light ? 0.26 : 0.22;
    p.hero.a  = p.surface.a;
    return p;
}

UIColor *AXUIColor(AXColor4 c) {
    return [UIColor colorWithRed:c.r green:c.g blue:c.b alpha:c.a];
}

AXColor4 AXLiquidBodyTint(AXColor4 tint, BOOL light, CGFloat x, CGFloat y) {
    x = MAX(0.0, MIN(1.0, x));
    y = MAX(0.0, MIN(1.0, y));
    CGFloat diagonal = MAX(0.0, MIN(1.0, 1.0 - x * 0.62 - y * 1.22));
    CGFloat reflection = diagonal * diagonal;
    return AXMix(tint, (AXColor4){1,1,1,1}, (light ? 0.30 : 0.38) * reflection);
}

CGFloat AXLiquidBodyAlpha(CGFloat opacity, CGFloat x, CGFloat y) {
    x = MAX(0.0, MIN(1.0, x));
    y = MAX(0.0, MIN(1.0, y));
    CGFloat diagonal = MAX(0.0, MIN(1.0, 1.0 - x * 0.62 - y * 1.22));
    return opacity * (0.84 + 0.13 * diagonal * diagonal);
}

AXColor4 AXLiquidRimMix(AXColor4 upper, AXColor4 lower, CGFloat x, CGFloat y) {
    return AXMix(upper, lower, MAX(0.0, MIN(1.0, y * 0.84 + x * 0.16)));
}

CGFloat AXPulse(BOOL reduceMotion, NSTimeInterval time) {
    return reduceMotion ? 0.5 : (0.5 + 0.5 * sin(time * 0.42));
}

BOOL AXIsCompactLayout(CGSize display) {
    return display.width < display.height * 1.12;
}

CGFloat AXLayoutHeightForDisplay(CGSize display, BOOL compact) {
    if (!compact) return AXLayoutWideH;
    CGFloat h = AXLayoutCompactW * (display.height - 36.0) / MAX(240.0, display.width - 24.0);
    return MAX(640.0, MIN(1200.0, h));
}

CGFloat AXMaximumScale(CGSize display, BOOL compact) {
    CGFloat w = compact ? AXLayoutCompactW : AXLayoutWideW;
    CGFloat h = AXLayoutHeightForDisplay(display, compact);
    CGFloat pad = compact ? AXLayoutCompactPad : AXLayoutWidePad;
    return MAX(0.1, MIN((display.width - 16.0) / (w + 2 * pad),
                        (display.height - 24.0) / (h + 2 * pad)));
}

CGFloat AXDefaultScale(CGSize display, BOOL compact) {
    CGFloat fitted = AXMaximumScale(display, compact);
    if (!compact) {
        fitted = MIN(fitted, MAX(0.65, MIN(display.width / 1600.0, display.height / 1000.0)));
    }
    return fitted * 0.90;
}

CGFloat AXMinimumScale(CGSize display, BOOL compact) {
    CGFloat d = AXDefaultScale(display, compact);
    return MIN(AXMaximumScale(display, compact),
               compact ? d * 0.78 : MAX(0.1, d * 0.60));
}

CGFloat AXStrokeScale(CGFloat scale, CGFloat width, CGFloat height) {
    return MIN(scale, MIN(width, height) * 0.125);
}

BOOL AXReduceMotion(void) {
    return UIAccessibilityIsReduceMotionEnabled();
}

@interface Theme ()
@property (nonatomic, assign) NSUInteger currentIndex;
@end

@implementation Theme

+ (instancetype)sharedTheme {
    static dispatch_once_t onceToken;
    static Theme *theme = nil;
    dispatch_once(&onceToken, ^{
        theme = [[Theme alloc] init];
        NSInteger stored = [[NSUserDefaults standardUserDefaults] integerForKey:AXThemeIndexKey];
        if (stored < 0 || stored >= (NSInteger)AXThemeCount) stored = AXThemeGraphite;
        theme.currentIndex = (NSUInteger)stored;
    });
    return theme;
}

- (NSUInteger)paletteIndex { return self.currentIndex; }

- (void)setPaletteIndex:(NSUInteger)index {
    self.currentIndex = index >= AXThemeCount ? AXThemeCount - 1 : index;
    [[NSUserDefaults standardUserDefaults] setInteger:(NSInteger)self.currentIndex forKey:AXThemeIndexKey];
}

- (void)advancePalette {
    [self setPaletteIndex:(self.currentIndex + 1) % AXThemeCount];
}

- (NSString *)paletteName {
    AXThemePalette p = AXThemeGet(self.currentIndex);
    return [NSString stringWithFormat:@"%s · %s", p.name, p.subtitle];
}

- (AXThemePalette)palette { return AXThemeGet(self.currentIndex); }
- (AXThemePalette)material { return AXMaterialFromPalette([self palette]); }

+ (AXColor4)backgroundTopForPalette:(AXThemePalette)p { return p.hero; }
+ (AXColor4)backgroundBottomForPalette:(AXThemePalette)p { return p.shell; }

+ (UIColor *)ink       { return AXUIColor([Theme sharedTheme].material.ink); }
+ (UIColor *)muted     { return AXUIColor([Theme sharedTheme].material.muted); }
+ (UIColor *)accent    { return AXUIColor([Theme sharedTheme].material.accent); }
+ (UIColor *)onAccent  { return AXUIColor([Theme sharedTheme].material.onAccent); }
+ (UIColor *)border    { return AXUIColor([Theme sharedTheme].material.border); }
+ (UIColor *)surfaceFill { return AXUIColor([Theme sharedTheme].material.surface); }
+ (UIColor *)shellFill   { return AXUIColor([Theme sharedTheme].material.shell); }
+ (UIColor *)hoverFill   { return AXUIColor([Theme sharedTheme].material.hover); }
+ (UIColor *)activeFill  { return AXUIColor([Theme sharedTheme].material.active); }
+ (UIColor *)heroFill    { return AXUIColor([Theme sharedTheme].material.hero); }

+ (CGFloat)scale {
    CGSize d = [UIScreen mainScreen].bounds.size;
    return AXDefaultScale(d, AXIsCompactLayout(d));
}

+ (UIFont *)fontHero     { return [UIFont systemFontOfSize:28.0 * [self scale] weight:UIFontWeightBold]; }
+ (UIFont *)fontPage     { return [UIFont systemFontOfSize:25.0 * [self scale] weight:UIFontWeightSemibold]; }
+ (UIFont *)fontBody     { return [UIFont systemFontOfSize:19.0 * [self scale] weight:UIFontWeightRegular]; }
+ (UIFont *)fontLabel    { return [UIFont systemFontOfSize:13.0 * [self scale] weight:UIFontWeightMedium]; }
+ (UIFont *)fontFootnote { return [UIFont systemFontOfSize:10.0 * [self scale] weight:UIFontWeightRegular]; }

+ (void)applyLiquidBodyToView:(UIView *)view
                      palette:(AXThemePalette)p
                       radius:(CGFloat)radius
                      opacity:(CGFloat)opacity {
    view.backgroundColor = [UIColor clearColor];
    view.layer.cornerRadius = radius;
    view.layer.masksToBounds = YES;

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:p.light ? UIBlurEffectStyleLight : UIBlurEffectStyleDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    blurView.userInteractionEnabled = NO;
    [view insertSubview:blurView atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [blurView.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
        [blurView.topAnchor constraintEqualToAnchor:view.topAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:view.bottomAnchor]
    ]];

    // 对角反射层：CAGradientLayer 沿左上→右下，start/end 对应 x*0.62 + y*1.22。
    CAGradientLayer *reflection = [CAGradientLayer layer];
    reflection.frame = view.bounds;
    reflection.startPoint = CGPointMake(0.0, 0.0);
    reflection.endPoint = CGPointMake(0.62, 1.22);
    AXColor4 body = AXLiquidBodyTint(p.surface, p.light, 0.0, 1.0);
    AXColor4 high = AXLiquidBodyTint(p.surface, p.light, 0.0, 0.0);
    reflection.colors = @[
        (__bridge id)AXUIColor(AXOpacity(high, AXLiquidBodyAlpha(p.surface.a * opacity, 0, 0))).CGColor,
        (__bridge id)AXUIColor(AXOpacity(body, AXLiquidBodyAlpha(p.surface.a * opacity, 0, 1))).CGColor
    ];
    reflection.cornerRadius = radius;
    [view.layer insertSublayer:reflection atIndex:1];
    objc_setAssociatedObject(view, _cmd, reflection, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (void)applyLiquidEdgesToView:(UIView *)view
                       palette:(AXThemePalette)p
                        radius:(CGFloat)radius
                      emphasis:(CGFloat)emphasis {
    CGFloat s = AXStrokeScale([self scale], CGRectGetWidth(view.bounds), CGRectGetHeight(view.bounds));
    CGFloat e = MAX(0.0, MIN(1.0, emphasis));
    AXColor4 white = (AXColor4){1,1,1,1};
    AXColor4 shade = AXMix(p.hero, (AXColor4){0.035,0.045,0.06,1}, 0.54);

    CAShapeLayer *outer = [CAShapeLayer layer];
    outer.frame = view.bounds;
    outer.path = [UIBezierPath bezierPathWithRoundedRect:view.bounds cornerRadius:radius].CGPath;
    outer.fillColor = [UIColor clearColor].CGColor;
    outer.lineWidth = 0.85 * s;
    AXColor4 upper = AXOpacity(white, (p.light ? 0.57 : 0.35) + 0.12 * e);
    AXColor4 lower = AXOpacity(shade, p.light ? 0.22 : 0.45);
    outer.strokeColor = AXUIColor(AXLiquidRimMix(upper, lower, 0, 1)).CGColor;
    [view.layer addSublayer:outer];

    CGFloat inset = 1.4 * s;
    CGRect innerRect = CGRectInset(view.bounds, inset, inset);
    if (CGRectGetWidth(innerRect) > 0 && CGRectGetHeight(innerRect) > 0) {
        CAShapeLayer *inner = [CAShapeLayer layer];
        inner.frame = view.bounds;
        inner.path = [UIBezierPath bezierPathWithRoundedRect:innerRect
                                               cornerRadius:MAX(0, radius - inset)].CGPath;
        inner.fillColor = [UIColor clearColor].CGColor;
        inner.lineWidth = 0.65 * s;
        AXColor4 iUpper = AXOpacity(white, p.light ? 0.14 : 0.085);
        AXColor4 iLower = AXOpacity(AXMix(white, p.accent, 0.12), p.light ? 0.38 : 0.22);
        inner.strokeColor = AXUIColor(AXLiquidRimMix(iUpper, iLower, 0, 1)).CGColor;
        [view.layer addSublayer:inner];
    }
}

+ (void)applyShellToView:(UIView *)view
                 palette:(AXThemePalette)p
                  radius:(CGFloat)radius
                   scale:(CGFloat)scale
                   alpha:(CGFloat)alpha {
    CGFloat s = MAX(0.1, MIN(4.0, scale));
    AXColor4 shade = AXMix(p.hero, (AXColor4){0.03,0.04,0.06,1}, 0.60);
    for (int i = 3; i >= 1; i--) {
        CGFloat spread = MAX(0.0, 5.0 * s - 1.0) * i / 3.0;
        view.layer.shadowColor = AXUIColor(AXOpacity(shade, (p.light ? 0.025 : 0.045) * (4 - i) / 3.0 * alpha)).CGColor;
        view.layer.shadowRadius = radius + spread;
        view.layer.shadowOffset = CGSizeMake(-spread, -spread);
        view.layer.shadowOpacity = 1.0;
    }
    [self applyLiquidBodyToView:view palette:p radius:radius opacity:alpha];
    [self applyLiquidEdgesToView:view palette:p radius:radius emphasis:0.22];
}

+ (CAShapeLayer *)emblemLayerWithSize:(CGFloat)size palette:(AXThemePalette)p {
    CAShapeLayer *layer = [CAShapeLayer layer];
    layer.frame = CGRectMake(0, 0, size, size);
    layer.cornerRadius = size * 0.28;
    layer.fillColor = [UIColor clearColor].CGColor;

    UIBezierPath *ribbon = [UIBezierPath bezierPath];
    NSArray<NSValue *> *points = @[
        [NSValue valueWithCGPoint:CGPointMake(size * 0.72, size * 0.28)],
        [NSValue valueWithCGPoint:CGPointMake(size * 0.42, size * 0.28)],
        [NSValue valueWithCGPoint:CGPointMake(size * 0.29, size * 0.405)],
        [NSValue valueWithCGPoint:CGPointMake(size * 0.70, size * 0.595)],
        [NSValue valueWithCGPoint:CGPointMake(size * 0.575, size * 0.72)],
        [NSValue valueWithCGPoint:CGPointMake(size * 0.28, size * 0.72)]
    ];
    [ribbon moveToPoint:[points[0] CGPointValue]];
    for (NSInteger i = 1; i < points.count; i++) {
        [ribbon addLineToPoint:[points[i] CGPointValue]];
    }
    layer.path = ribbon.CGPath;
    layer.strokeColor = AXUIColor(p.ink).CGColor;
    layer.lineWidth = size * 0.105;
    layer.lineJoin = kCALineJoinRound;
    layer.lineCap = kCALineCapRound;

    CAShapeLayer *dot = [CAShapeLayer layer];
    dot.frame = layer.frame;
    UIBezierPath *dotPath = [UIBezierPath bezierPathWithArcCenter:CGPointMake(size * 0.82, size * 0.79)
                                                           radius:size * 0.023
                                                       startAngle:0 endAngle:M_PI * 2 clockwise:YES];
    dot.path = dotPath.CGPath;
    dot.fillColor = AXUIColor(AXOpacity(p.ink, 0.62)).CGColor;
    [layer addSublayer:dot];
    return layer;
}

+ (UIButton *)visionButtonWithTitle:(NSString *)title {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    button.titleLabel.font = [self fontBody];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[self ink] forState:UIControlStateNormal];
    [button setTitleColor:[self onAccent] forState:UIControlStateHighlighted];
    AXThemePalette p = [Theme sharedTheme].material;
    [self applyLiquidBodyToView:button palette:p radius:[self buttonRadius] opacity:1.0];
    [self applyLiquidEdgesToView:button palette:p radius:[self buttonRadius] emphasis:0.0];
    return button;
}

+ (CGFloat)navCardWidth { return 208.0 * [self scale]; }
+ (CGFloat)navCardHeight { return 64.0 * [self scale]; }
+ (CGFloat)toggleWidth { return 44.0 * [self scale]; }
+ (CGFloat)toggleHeight { return 24.0 * [self scale]; }
+ (CGFloat)buttonRadius { return 28.0 * [self scale]; }

+ (UIView *)navigationCardWithTitle:(NSString *)title subtitle:(NSString *)subtitle index:(NSUInteger)index {
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [self navCardWidth], [self navCardHeight])];
    AXThemePalette p = [Theme sharedTheme].material;
    [self applyLiquidBodyToView:card palette:p radius:20.0 * [self scale] opacity:1.0];
    [self applyLiquidEdgesToView:card palette:p radius:20.0 * [self scale] emphasis:0.15];

    UIView *icon = [[UIView alloc] initWithFrame:CGRectMake(12 * [self scale], 14 * [self scale],
                                                            36 * [self scale], 36 * [self scale])];
    icon.layer.cornerRadius = 11 * [self scale];
    icon.backgroundColor = AXUIColor(p.accent);
    [card addSubview:icon];

    CGFloat x = 58 * [self scale];
    UILabel *main = [[UILabel alloc] initWithFrame:CGRectMake(x, 10 * [self scale],
                                                              [self navCardWidth] - x - 8, 26 * [self scale])];
    main.text = title;
    main.font = [UIFont systemFontOfSize:19 * [self scale] weight:UIFontWeightSemibold];
    main.textColor = AXUIColor(p.ink);
    [card addSubview:main];

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(x, 36 * [self scale],
                                                             [self navCardWidth] - x - 8, 15 * [self scale])];
    sub.text = subtitle;
    sub.font = [UIFont systemFontOfSize:10.5 * [self scale] weight:UIFontWeightRegular];
    sub.textColor = AXUIColor(p.muted);
    [card addSubview:sub];

    UILabel *num = [[UILabel alloc] initWithFrame:CGRectMake([self navCardWidth] - 24 * [self scale],
                                                             10 * [self scale], 16 * [self scale], 14 * [self scale])];
    num.text = @(index).stringValue;
    num.font = [UIFont systemFontOfSize:10 * [self scale] weight:UIFontWeightMedium];
    num.textColor = AXUIColor(p.muted);
    [card addSubview:num];
    return card;
}

+ (UIView *)toggleViewOn:(BOOL)on {
    UIView *track = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [self toggleWidth], [self toggleHeight])];
    AXThemePalette p = [Theme sharedTheme].material;
    track.layer.cornerRadius = 12 * [self scale];
    track.backgroundColor = AXUIColor(on ? p.accent : AXOpacity(p.muted, 0.35));
    CGFloat knob = 9 * [self scale];
    UIView *knobView = [[UIView alloc] initWithFrame:CGRectMake(on ? [self toggleWidth] - knob - 2 * [self scale] : 2 * [self scale],
                                                                2 * [self scale], knob, knob)];
    knobView.layer.cornerRadius = knob / 2.0;
    knobView.backgroundColor = AXUIColor(p.onAccent);
    [track addSubview:knobView];
    return track;
}

@end
