#import "OrielCEFBridge.h"

#if !TARGET_OS_OSX

@implementation OrielCEFRuntime
+ (BOOL)isFrameworkOnDisk { return NO; }
+ (BOOL)isEmbeddedHostingCompiled { return NO; }
+ (BOOL)isReady { return NO; }
+ (BOOL)startIfNeeded:(NSError **)error { (void)error; return NO; }
+ (void)shutdown {}
+ (NSURL *)frameworkURL { return nil; }
+ (NSString *)statusSummary { return @"CEF is Mac-only."; }
@end

@implementation OrielCEFHost
- (instancetype)init {
    return [super init];
}
- (NSURL *)URL { return nil; }
- (NSString *)title { return @""; }
- (BOOL)isLoading { return NO; }
- (BOOL)canGoBack { return NO; }
- (BOOL)canGoForward { return NO; }
- (void)loadURL:(NSURL *)url { (void)url; }
- (void)goBack {}
- (void)goForward {}
- (void)reload {}
- (void)stopLoading {}
- (void)clearCookiesAndCache {}
@end

#else // TARGET_OS_OSX

#import <AppKit/AppKit.h>

static NSURL *OrielCEFFrameworkURL(void) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSBundle *bundle = NSBundle.mainBundle;
    NSArray<NSURL *> *candidates = @[
        [bundle.privateFrameworksURL URLByAppendingPathComponent:@"Chromium Embedded Framework.framework"],
        [bundle.bundleURL URLByAppendingPathComponent:@"Contents/Frameworks/Chromium Embedded Framework.framework"],
    ];
    for (NSURL *url in candidates) {
        if ([fm fileExistsAtPath:url.path]) { return url; }
    }
    NSArray<NSURL *> *supports = [fm URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
    if (supports.count > 0) {
        NSURL *root = [[supports[0] URLByAppendingPathComponent:@"Oriel"]
                       URLByAppendingPathComponent:@"CEF"];
        NSArray<NSURL *> *local = @[
            [root URLByAppendingPathComponent:@"Chromium Embedded Framework.framework"],
            [[root URLByAppendingPathComponent:@"Release"]
             URLByAppendingPathComponent:@"Chromium Embedded Framework.framework"],
        ];
        for (NSURL *url in local) {
            if ([fm fileExistsAtPath:url.path]) { return url; }
        }
    }
    return nil;
}

@implementation OrielCEFRuntime

+ (BOOL)isFrameworkOnDisk {
    return OrielCEFFrameworkURL() != nil;
}

+ (BOOL)isEmbeddedHostingCompiled {
#if defined(ORIEL_HAS_CEF) && ORIEL_HAS_CEF
    return YES;
#else
    return NO;
#endif
}

+ (BOOL)isReady {
    return self.isFrameworkOnDisk && self.isEmbeddedHostingCompiled;
}

+ (NSURL *)frameworkURL {
    return OrielCEFFrameworkURL();
}

+ (NSString *)statusSummary {
    if (!self.isFrameworkOnDisk) {
        return @"Oriel Engine framework not installed. Run Scripts/fetch-cef-macos.sh (or build the Mac DMG).";
    }
    if (!self.isEmbeddedHostingCompiled) {
        return @"Oriel Engine framework on disk, but this binary was not built with ORIEL_HAS_CEF. Run Scripts/build-oriel-engine-macos.sh and rebuild.";
    }
    return @"Oriel Engine ready — Blink paints inside Oriel tabs.";
}

+ (BOOL)startIfNeeded:(NSError **)error {
#if defined(ORIEL_HAS_CEF) && ORIEL_HAS_CEF
    extern BOOL OrielCEFStartImpl(NSError **);
    return OrielCEFStartImpl(error);
#else
    if (error) {
        *error = [NSError errorWithDomain:@"net.inveil.oriel.cef"
                                     code:1
                                 userInfo:@{NSLocalizedDescriptionKey: self.statusSummary}];
    }
    return NO;
#endif
}

+ (void)shutdown {
#if defined(ORIEL_HAS_CEF) && ORIEL_HAS_CEF
    extern void OrielCEFShutdownImpl(void);
    OrielCEFShutdownImpl();
#endif
}

@end

#if defined(ORIEL_HAS_CEF) && ORIEL_HAS_CEF

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-parameter"

#include "include/cef_app.h"
#include "include/cef_browser.h"
#include "include/cef_client.h"
#include "include/cef_cookie.h"
#include "include/wrapper/cef_library_loader.h"

#include <atomic>
#include <string>

namespace {

std::atomic<bool> g_cef_started{false};
CefRefPtr<CefApp> g_app;

class OrielApp : public CefApp, public CefBrowserProcessHandler {
public:
    CefRefPtr<CefBrowserProcessHandler> GetBrowserProcessHandler() override { return this; }
    IMPLEMENT_REFCOUNTING(OrielApp);
};

class OrielClient : public CefClient,
                    public CefDisplayHandler,
                    public CefLifeSpanHandler,
                    public CefLoadHandler,
                    public CefDownloadHandler {
public:
    explicit OrielClient(OrielCEFHost *host) : host_(host) {}

    CefRefPtr<CefDisplayHandler> GetDisplayHandler() override { return this; }
    CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() override { return this; }
    CefRefPtr<CefLoadHandler> GetLoadHandler() override { return this; }
    CefRefPtr<CefDownloadHandler> GetDownloadHandler() override { return this; }

    void OnAfterCreated(CefRefPtr<CefBrowser> browser) override { browser_ = browser; Notify(); }
    void OnBeforeClose(CefRefPtr<CefBrowser> browser) override {
        if (browser_ && browser_->IsSame(browser)) { browser_ = nullptr; }
    }

    void OnTitleChange(CefRefPtr<CefBrowser> browser, const CefString &title) override {
        title_ = title.ToString();
        Notify();
    }
    void OnAddressChange(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, const CefString &url) override {
        if (frame->IsMain()) {
            url_ = url.ToString();
            Notify();
        }
    }
    void OnLoadingStateChange(CefRefPtr<CefBrowser> browser, bool isLoading, bool canGoBack, bool canGoForward) override {
        loading_ = isLoading;
        can_back_ = canGoBack;
        can_forward_ = canGoForward;
        Notify();
    }
    bool OnBeforeDownload(CefRefPtr<CefBrowser> browser,
                          CefRefPtr<CefDownloadItem> item,
                          const CefString &suggested_name,
                          CefRefPtr<CefBeforeDownloadCallback> callback) override {
        NSString *name = [NSString stringWithUTF8String:suggested_name.ToString().c_str()];
        NSString *urlStr = [NSString stringWithUTF8String:item->GetURL().ToString().c_str()];
        NSURL *url = [NSURL URLWithString:urlStr];
        OrielCEFHost *host = host_;
        dispatch_async(dispatch_get_main_queue(), ^{
            id<OrielCEFHostDelegate> del = host.delegate;
            if (url && [del respondsToSelector:@selector(cefHostDidStartDownload:suggestedName:)]) {
                [del cefHostDidStartDownload:url suggestedName:(name ?: @"download")];
            }
        });
        callback->Continue("", false);
        return true;
    }

    CefRefPtr<CefBrowser> browser() const { return browser_; }
    std::string url() const { return url_; }
    std::string title() const { return title_; }
    bool loading() const { return loading_; }
    bool can_back() const { return can_back_; }
    bool can_forward() const { return can_forward_; }

private:
    void Notify() {
        OrielCEFHost *host = host_;
        dispatch_async(dispatch_get_main_queue(), ^{
            id<OrielCEFHostDelegate> del = host.delegate;
            if ([del respondsToSelector:@selector(cefHostDidChangeState)]) {
                [del cefHostDidChangeState];
            }
        });
    }

    __weak OrielCEFHost *host_;
    CefRefPtr<CefBrowser> browser_;
    std::string url_;
    std::string title_;
    bool loading_ = false;
    bool can_back_ = false;
    bool can_forward_ = false;
    IMPLEMENT_REFCOUNTING(OrielClient);
};

} // namespace

BOOL OrielCEFStartImpl(NSError **error) {
    if (g_cef_started.load()) { return YES; }

    CefScopedLibraryLoader loader;
    if (!loader.LoadInMain()) {
        if (error) {
            *error = [NSError errorWithDomain:@"net.inveil.oriel.cef" code:2
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to load Chromium Embedded Framework."}];
        }
        return NO;
    }

    CefMainArgs args(0, nullptr);
    CefSettings settings;
    settings.no_sandbox = true;
    g_app = new OrielApp();
    if (!CefInitialize(args, settings, g_app, nullptr)) {
        if (error) {
            *error = [NSError errorWithDomain:@"net.inveil.oriel.cef" code:3
                                     userInfo:@{NSLocalizedDescriptionKey: @"CefInitialize failed."}];
        }
        return NO;
    }
    g_cef_started.store(true);
    [NSTimer scheduledTimerWithTimeInterval:0.012 repeats:YES block:^(__unused NSTimer *timer) {
        if (g_cef_started.load()) {
            CefDoMessageLoopWork();
        }
    }];
    return YES;
}

void OrielCEFShutdownImpl(void) {
    if (!g_cef_started.exchange(false)) { return; }
    CefShutdown();
    g_app = nullptr;
}

@interface OrielCEFHost () {
    NSView *_container;
    CefRefPtr<OrielClient> _client;
}
@end

@implementation OrielCEFHost

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super init];
    if (self) {
        _container = [[NSView alloc] initWithFrame:frame];
        _container.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        _container.wantsLayer = YES;
        NSError *err = nil;
        if (![OrielCEFRuntime startIfNeeded:&err]) {
            NSTextField *label = [NSTextField labelWithString:err.localizedDescription ?: @"CEF unavailable"];
            label.frame = NSInsetRect(_container.bounds, 16, 16);
            label.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
            [_container addSubview:label];
        } else {
            _client = new OrielClient(self);
            CefWindowInfo info;
            info.SetAsChild((__bridge void *)_container,
                            CefRect(0, 0, (int)frame.size.width, (int)frame.size.height));
            CefBrowserSettings browserSettings;
            CefBrowserHost::CreateBrowser(info, _client, "about:blank", browserSettings, nullptr, nullptr);
        }
    }
    return self;
}

- (NSView *)view { return _container; }
- (NSURL *)URL {
    if (!_client) { return nil; }
    NSString *s = [NSString stringWithUTF8String:_client->url().c_str()];
    return s.length ? [NSURL URLWithString:s] : nil;
}
- (NSString *)title {
    if (!_client) { return @""; }
    return [NSString stringWithUTF8String:_client->title().c_str()] ?: @"";
}
- (BOOL)isLoading { return _client ? _client->loading() : NO; }
- (BOOL)canGoBack { return _client ? _client->can_back() : NO; }
- (BOOL)canGoForward { return _client ? _client->can_forward() : NO; }

- (void)loadURL:(NSURL *)url {
    if (!_client || !url) { return; }
    if (auto b = _client->browser()) {
        b->GetMainFrame()->LoadURL(url.absoluteString.UTF8String);
    }
}
- (void)goBack { if (_client && _client->browser()) { _client->browser()->GoBack(); } }
- (void)goForward { if (_client && _client->browser()) { _client->browser()->GoForward(); } }
- (void)reload { if (_client && _client->browser()) { _client->browser()->Reload(); } }
- (void)stopLoading { if (_client && _client->browser()) { _client->browser()->StopLoad(); } }
- (void)clearCookiesAndCache {
    if (!g_cef_started.load()) { return; }
    CefRefPtr<CefCookieManager> mgr = CefCookieManager::GetGlobalManager(nullptr);
    if (mgr) { mgr->DeleteCookies("", "", nullptr); }
}

@end

#pragma clang diagnostic pop

#else // stub without ORIEL_HAS_CEF

@interface OrielCEFHost ()
@property (nonatomic, strong) NSView *container;
@property (nonatomic, copy) NSString *currentTitle;
@property (nonatomic, strong, nullable) NSURL *currentURL;
@end

@implementation OrielCEFHost

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super init];
    if (self) {
        _container = [[NSView alloc] initWithFrame:frame];
        _container.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        _container.wantsLayer = YES;
        _container.layer.backgroundColor = NSColor.windowBackgroundColor.CGColor;
        _currentTitle = @"";
        NSTextField *label = [NSTextField wrappingLabelWithString:[OrielCEFRuntime statusSummary]];
        label.frame = NSInsetRect(_container.bounds, 20, 20);
        label.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        label.textColor = NSColor.secondaryLabelColor;
        [_container addSubview:label];
    }
    return self;
}

- (NSView *)view { return self.container; }
- (NSURL *)URL { return self.currentURL; }
- (NSString *)title { return self.currentTitle ?: @""; }
- (BOOL)isLoading { return NO; }
- (BOOL)canGoBack { return NO; }
- (BOOL)canGoForward { return NO; }
- (void)loadURL:(NSURL *)url {
    self.currentURL = url;
    self.currentTitle = url.host ?: url.absoluteString ?: @"";
    [self.delegate cefHostDidChangeState];
}
- (void)goBack {}
- (void)goForward {}
- (void)reload {}
- (void)stopLoading {}
- (void)clearCookiesAndCache {}

@end

#endif // ORIEL_HAS_CEF
#endif // TARGET_OS_OSX
