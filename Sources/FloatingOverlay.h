#import <UIKit/UIKit.h>
#import "FloatingBallView.h"

NS_ASSUME_NONNULL_BEGIN

@interface FloatingOverlay : NSObject

+ (instancetype)sharedOverlay;

- (void)setCrossAppMode:(BOOL)enabled;
- (BOOL)isCrossAppMode;
- (void)show;
- (void)hide;
- (BOOL)isVisible;
- (CGFloat)currentWindowLevel;

@end

NS_ASSUME_NONNULL_END
