#import "GradientBackgroundView.h"
#import "Theme.h"

@implementation GradientBackgroundView

+ (Class)layerClass {
    return [CAGradientLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self refreshGradient];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(refreshGradient)
                                                     name:@"AXThemeDidChangeNotification"
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)refreshGradient {
    AXThemePalette p = [Theme sharedTheme].material;
    AXColor4 top = [Theme backgroundTopForPalette:p];
    AXColor4 bottom = [Theme backgroundBottomForPalette:p];
    CAGradientLayer *layer = (CAGradientLayer *)self.layer;
    layer.colors = @[
        (__bridge id)AXUIColor(AXOpacity(top, 1.0)).CGColor,
        (__bridge id)AXUIColor(AXOpacity(bottom, 1.0)).CGColor
    ];
    layer.locations = @[@0.0, @1.0];
    layer.startPoint = CGPointMake(0.0, 0.0);
    layer.endPoint = CGPointMake(1.0, 1.0);
}

@end
