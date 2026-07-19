#import <Foundation/Foundation.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface OrielCEFRuntime : NSObject
+ (BOOL)isFrameworkOnDisk;
+ (BOOL)isEmbeddedHostingCompiled;
+ (BOOL)isReady;
+ (BOOL)startIfNeeded:(NSError * _Nullable * _Nullable)error;
+ (void)shutdown;
+ (nullable NSURL *)frameworkURL;
+ (NSString *)statusSummary;
@end

@protocol OrielCEFHostDelegate <NSObject>
- (void)cefHostDidChangeState;
- (void)cefHostDidStartDownload:(NSURL *)url suggestedName:(NSString *)name;
@end

@interface OrielCEFHost : NSObject
#if TARGET_OS_OSX
- (instancetype)initWithFrame:(NSRect)frame;
@property (nonatomic, readonly) NSView *view;
#else
- (instancetype)init;
#endif
@property (nonatomic, weak, nullable) id<OrielCEFHostDelegate> delegate;
@property (nonatomic, readonly, nullable) NSURL *URL;
@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly, getter=isLoading) BOOL loading;
@property (nonatomic, readonly) BOOL canGoBack;
@property (nonatomic, readonly) BOOL canGoForward;
- (void)loadURL:(NSURL *)url;
- (void)goBack;
- (void)goForward;
- (void)reload;
- (void)stopLoading;
- (void)clearCookiesAndCache;
@end

NS_ASSUME_NONNULL_END
