#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface AXHIDTouchManager : NSObject

+ (instancetype)sharedManager;

- (BOOL)startWithCenterProvider:(CGPoint (^)(void))centerProvider
                    moveHandler:(void (^)(CGPoint point))moveHandler
                     tapHandler:(nullable void (^)(void))tapHandler;
- (void)stop;

@property (nonatomic, readonly) BOOL running;

@end

NS_ASSUME_NONNULL_END
