#ifndef DARKSWORD_API_SHIM_H
#define DARKSWORD_API_SHIM_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const DarkSwordShimErrorDomain;

typedef NS_ENUM(NSInteger, DarkSwordShimErrorCode) {
    DarkSwordShimErrorBackendNotBound   = 1,
    DarkSwordShimErrorNullOutput        = 2,
    DarkSwordShimErrorKCallUnavailable  = 3,
    DarkSwordShimErrorRemoteUnavailable = 4
};

typedef BOOL (^DarkSwordInitBlock)(NSError **error);
typedef BOOL (^DarkSwordKReadBlock)(uint64_t address, uint64_t *value, NSError **error);
typedef BOOL (^DarkSwordKWriteBlock)(uint64_t address, uint64_t value, NSError **error);
typedef BOOL (^DarkSwordKCallBlock)(uint64_t functionAddress,
                                    NSArray<NSNumber *> *arguments,
                                    uint64_t *result,
                                    NSError **error);

FOUNDATION_EXPORT NSError *DSError(NSInteger code, NSString *format, ...) NS_FORMAT_FUNCTION(2,3);

@interface DarkSwordAPIShim : NSObject

+ (instancetype)sharedShim;
- (BOOL)isBackendBound;
- (void)bindLaraBackend;
- (void)setInitBlock:(DarkSwordInitBlock)block;
- (void)setKreadBlock:(DarkSwordKReadBlock)block;
- (void)setKwriteBlock:(DarkSwordKWriteBlock)block;
- (void)setKcallBlock:(DarkSwordKCallBlock)block;
- (void)initExploitWithCompletion:(void (^_Nullable)(BOOL success, NSError * _Nullable error))completion;
- (BOOL)kread64:(uint64_t)address value:(uint64_t *)value error:(NSError **)error;
- (BOOL)kwrite64:(uint64_t)address value:(uint64_t)value error:(NSError **)error;
- (BOOL)kcall:(uint64_t)functionAddress
    arguments:(NSArray<NSNumber *> *)arguments
       result:(uint64_t *)result
        error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

#endif
