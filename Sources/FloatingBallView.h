#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FloatingBallMenuItem : NSObject

@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly) void (^action)(void);

- (instancetype)initWithTitle:(NSString *)title action:(void (^)(void))action;

@end

@interface FloatingBallView : UIView

@property (nonatomic, copy) NSArray<FloatingBallMenuItem *> *menuItems;
@property (nonatomic, copy, nullable) void (^onTap)(void);
@property (nonatomic, assign) BOOL menuExpanded;

- (void)setMenuExpanded:(BOOL)menuExpanded animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
