#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// 13 通道与 apple-visionpro-interaction/app/jni/src/SpatialTheme.h::Palette 一一对应。
typedef NS_ENUM(NSUInteger, AXThemeIndex) {
    AXThemePorcelain = 0,   // 瓷白
    AXThemeMist,            // 雾透
    AXThemeGraphite,        // 石墨
    AXThemeBay,             // 海湾
    AXThemeForest,          // 松林
    AXThemeIris,            // 鸢尾
    AXThemeSand,            // 暖砂
    AXThemeCount
};

typedef struct {
    CGFloat r, g, b, a;
} AXColor4;

typedef struct {
    const char *name;
    const char *subtitle;
    BOOL light;
    AXColor4 shell, sidebar, surface, field, hover, active;
    AXColor4 ink, muted, accent, onAccent, border, hero, heroInk;
} AXThemePalette;

static inline AXColor4 AXRGBA(int r, int g, int b, int a) {
    return (AXColor4){r / 255.0, g / 255.0, b / 255.0, a / 255.0};
}

FOUNDATION_EXPORT AXThemePalette AXThemeGet(NSUInteger index);
FOUNDATION_EXPORT AXThemePalette AXMaterialFromPalette(AXThemePalette palette);
FOUNDATION_EXPORT UIColor *AXUIColor(AXColor4 c);

// LiquidBody 对角反射公式。
FOUNDATION_EXPORT AXColor4 AXLiquidBodyTint(AXColor4 tint, BOOL light, CGFloat x, CGFloat y);
FOUNDATION_EXPORT CGFloat AXLiquidBodyAlpha(CGFloat opacity, CGFloat x, CGFloat y);
// LiquidRim 描边渐变：y*0.84 + x*0.16。
FOUNDATION_EXPORT AXColor4 AXLiquidRimMix(AXColor4 upper, AXColor4 lower, CGFloat x, CGFloat y);
FOUNDATION_EXPORT CGFloat AXPulse(BOOL reduceMotion, NSTimeInterval time);

FOUNDATION_EXPORT CGFloat const AXLayoutWideW;
FOUNDATION_EXPORT CGFloat const AXLayoutWideH;
FOUNDATION_EXPORT CGFloat const AXLayoutWidePad;
FOUNDATION_EXPORT CGFloat const AXLayoutCompactW;
FOUNDATION_EXPORT CGFloat const AXLayoutCompactPad;

FOUNDATION_EXPORT BOOL AXIsCompactLayout(CGSize display);
FOUNDATION_EXPORT CGFloat AXLayoutHeightForDisplay(CGSize display, BOOL compact);
FOUNDATION_EXPORT CGFloat AXMaximumScale(CGSize display, BOOL compact);
FOUNDATION_EXPORT CGFloat AXDefaultScale(CGSize display, BOOL compact);
FOUNDATION_EXPORT CGFloat AXMinimumScale(CGSize display, BOOL compact);
FOUNDATION_EXPORT CGFloat AXStrokeScale(CGFloat scale, CGFloat width, CGFloat height);
FOUNDATION_EXPORT BOOL AXReduceMotion(void);

@interface Theme : NSObject

+ (instancetype)sharedTheme;
@property (nonatomic, assign) NSUInteger paletteIndex;
@property (nonatomic, readonly) AXThemePalette palette;
@property (nonatomic, readonly) AXThemePalette material;

- (void)advancePalette;
- (void)setPaletteIndex:(NSUInteger)index;
- (NSString *)paletteName;

+ (AXColor4)backgroundTopForPalette:(AXThemePalette)palette;
+ (AXColor4)backgroundBottomForPalette:(AXThemePalette)palette;

+ (UIColor *)ink;
+ (UIColor *)muted;
+ (UIColor *)accent;
+ (UIColor *)onAccent;
+ (UIColor *)border;
+ (UIColor *)surfaceFill;
+ (UIColor *)shellFill;
+ (UIColor *)hoverFill;
+ (UIColor *)activeFill;
+ (UIColor *)heroFill;

+ (UIFont *)fontHero;
+ (UIFont *)fontPage;
+ (UIFont *)fontBody;
+ (UIFont *)fontLabel;
+ (UIFont *)fontFootnote;
+ (CGFloat)scale;

+ (void)applyLiquidBodyToView:(UIView *)view
                      palette:(AXThemePalette)palette
                       radius:(CGFloat)radius
                      opacity:(CGFloat)opacity;
+ (void)applyLiquidEdgesToView:(UIView *)view
                       palette:(AXThemePalette)palette
                        radius:(CGFloat)radius
                      emphasis:(CGFloat)emphasis;
+ (void)applyShellToView:(UIView *)view
                 palette:(AXThemePalette)palette
                  radius:(CGFloat)radius
                   scale:(CGFloat)scale
                   alpha:(CGFloat)alpha;
+ (CAShapeLayer *)emblemLayerWithSize:(CGFloat)size palette:(AXThemePalette)palette;

+ (UIButton *)visionButtonWithTitle:(NSString *)title;
+ (CGFloat)navCardWidth;
+ (CGFloat)navCardHeight;
+ (CGFloat)toggleWidth;
+ (CGFloat)toggleHeight;
+ (CGFloat)buttonRadius;

// 布局常量落地：208×64*s 导航卡 + 44×24*s Toggle（按报告 SpatialUI.h 尺寸）。
+ (UIView *)navigationCardWithTitle:(NSString *)title subtitle:(NSString *)subtitle index:(NSUInteger)index;
+ (UIView *)toggleViewOn:(BOOL)on;

@end

NS_ASSUME_NONNULL_END
