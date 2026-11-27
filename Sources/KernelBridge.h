#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef BOOL (^DarkSwordRemoteInvocationBlock)(int pid,
                                               NSString *symbolOrSelector,
                                               NSArray<NSNumber *> *arguments,
                                               uint64_t *result,
                                               NSError **error);

FOUNDATION_EXPORT NSString *const DarkSwordBridgeErrorDomain;

@interface KernelBridge : NSObject

+ (instancetype)sharedBridge;

@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSNumber *> *offsetCache;
@property (nonatomic, copy, nullable) DarkSwordRemoteInvocationBlock remoteInvocationBlock;

- (void)initializeKernelWithCompletion:(void (^_Nullable)(BOOL success, NSString *message))completion;
- (void)setOffsetValue:(uint64_t)value forKey:(NSString *)key;
- (BOOL)validateOffsetCacheWithError:(NSError **)error;
- (int)pidForProcessNamed:(NSString *)name;
- (BOOL)injectSpringBoardWithWindowLevel:(double)windowLevel error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
