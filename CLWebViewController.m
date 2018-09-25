//
//  CLWebViewController.m
//  Labor
//
//  Created by Apple on 2018/4/3.
//  Copyright © 2018年 chilim. All rights reserved.
//

#import "CLWebViewController.h"
#import <StoreKit/StoreKit.h>
#import <objc/runtime.h>

/// URL 404
static NSString *const kCL404NotFoundURLKey = @"ax_404_not_found";
/// URL network error
static NSString *const kCLNetworkErrorURLKey = @"ax_network_error";

#define kCL404NotFoundHTMLPath [[NSBundle mainBundle] pathForResource:@"html.bundle/404" ofType:@"html"]
#define kCLNetworkErrorHTMLPath [[NSBundle mainBundle] pathForResource:@"html.bundle/neterror" ofType:@"html"]

@interface CLWebViewController ()<WKUIDelegate,WKNavigationDelegate>

///加载的url
@property (nonatomic, strong, readwrite) NSURL *url;

///webview的配置
@property (nonatomic, strong) WKWebViewConfiguration *configuration;

@property(strong, nonatomic) UIBarButtonItem *navigationBackBarButtonItem;
@property(strong, nonatomic) UIBarButtonItem *navigationCloseBarButtonItem;
///背景view
@property (nonatomic, strong) UIView *containerView;
///顶部显示文本
@property (nonatomic, strong) UILabel *backgroundLabel;
///进度条
@property (nonatomic, strong) UIProgressView *progressView;

@end

@implementation CLWebViewController

#pragma arguments
#pragma -mark 初始化方法

- (instancetype)initWithAddress:(NSString *)urlString{
    return [self initWithURL:[NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
}

- (instancetype)initWithURL:(NSURL*)url {
    if(self = [self init]) {
        _url = url;
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)url configuration:(WKWebViewConfiguration *)configuration{
    if(self = [self initWithURL:url]){
        _configuration = configuration;
    }
    return self;
}

- (instancetype)initWithAddress:(NSString *)urlString configuration:(WKWebViewConfiguration *)configuration{
    if(self = [self initWithAddress:urlString]){
        _configuration = configuration;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    ///加载超时默认30秒
    self.timeout = 30;
    ///是否清理缓存
    if (self.isClearWebCache) {
        [CLWebViewController clearWebCacheCompletion:^{
            NSLog(@"缓存清理完成!");
        }];
    }
    if (_url) {
        [self loadURL:_url];
    }
    [self setupView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    //设置进度条
    if (self.navigationController) {
        [self updateFrameOfProgressView];
        [self.navigationController.navigationBar addSubview:self.progressView];
    }
    [self updateNavigationItems];
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    if (self.navigationController) {
        [self.progressView removeFromSuperview];
    }
}

- (void)dealloc{
    [self.webView stopLoading];
    self.webView.UIDelegate = nil;
    self.webView.navigationDelegate = nil;
    [self.webView removeObserver:self forKeyPath:@"scrollView.contentOffset"];
    [self.webView removeObserver:self forKeyPath:@"title"];
    [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)loadURL:(NSURL *)url{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = self.timeout;
    _request = request;
    [self.webView loadRequest:_request];
}

///加载视图
- (void)setupView{
    [self.view addSubview:self.containerView];
    [self.containerView addSubview:self.backgroundLabel];
    [self.containerView addSubview:self.webView];
    [self.containerView bringSubviewToFront:self.backgroundLabel];
    self.progressView.frame = CGRectMake(0, 0, CGRectGetWidth(self.view.frame), 2);
    [self.view addSubview:self.progressView];
    [self.view bringSubviewToFront:self.progressView];
    self.progressView.progressTintColor = self.navigationController.navigationBar.tintColor;
}

#pragma -mark Actions methods
- (void)navigationItemHandleBack:(UIBarButtonItem *)sender {
    if ([self.webView canGoBack]) {
        [self.webView goBack];
        return;
    }
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)navigationIemHandleClose:(UIBarButtonItem *)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma -mark privates methods

- (void)updateTitleOfWebVC {
    NSString *title = self.title;
    title = title.length>0 ? title: [self.webView title];
    self.navigationItem.title = title.length>0 ? title : @"网页";
}

- (void)updateFrameOfProgressView {
    CGFloat progressBarHeight = 2.0f;
    CGRect navigationBarBounds = self.navigationController.navigationBar.bounds;
    CGRect barFrame = CGRectMake(0, navigationBarBounds.size.height - progressBarHeight, navigationBarBounds.size.width, progressBarHeight);
    self.progressView.frame = barFrame;
}

- (void)updateNavigationItems{
    [self.navigationItem setLeftBarButtonItems:nil animated:NO];
    if (self.webView.canGoBack) {
        UIBarButtonItem *spaceButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
        spaceButtonItem.width = 10;
        NSMutableArray *leftBarButtonItems = [NSMutableArray arrayWithArray:@[self.navigationBackBarButtonItem,spaceButtonItem]];
        
        [leftBarButtonItems addObject:self.navigationCloseBarButtonItem];
        [self.navigationItem setLeftBarButtonItems:leftBarButtonItems animated:NO];
    } else {
        [self.navigationItem setLeftBarButtonItems:nil animated:NO];
    }
}

///清理缓存
+ (void)clearWebCacheCompletion:(dispatch_block_t)completion {
    if (@available(iOS 9.0, *)) {
        NSSet *websiteDataTypes = [WKWebsiteDataStore allWebsiteDataTypes];
        NSDate *dateFrom = [NSDate dateWithTimeIntervalSince1970:0];
        [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:websiteDataTypes modifiedSince:dateFrom completionHandler:completion];
    } else {
        NSString *libraryDir = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)[0];
        NSString *bundleId  =  [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
        NSString *webkitFolderInLib = [NSString stringWithFormat:@"%@/WebKit",libraryDir];
        NSString *webKitFolderInCaches = [NSString stringWithFormat:@"%@/Caches/%@/WebKit",libraryDir,bundleId];
        NSString *webKitFolderInCachesfs = [NSString stringWithFormat:@"%@/Caches/%@/fsCachedData",libraryDir,bundleId];
        
        NSError *error;
        /* iOS8.0 WebView Cache path */
        [[NSFileManager defaultManager] removeItemAtPath:webKitFolderInCaches error:&error];
        [[NSFileManager defaultManager] removeItemAtPath:webkitFolderInLib error:nil];
        
        /* iOS7.0 WebView Cache path */
        [[NSFileManager defaultManager] removeItemAtPath:webKitFolderInCachesfs error:&error];
        if (completion) {
            completion();
        }
    }
}

///网页加载完成
- (void)cl_webViewDidFinishLoad{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [self updateTitleOfWebVC];
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSString *bundle = ([infoDictionary objectForKey:@"CFBundleDisplayName"]?:[infoDictionary objectForKey:@"CFBundleName"])?:[infoDictionary objectForKey:@"CFBundleIdentifier"];
    NSString *host = self.webView.URL.host;
    self.backgroundLabel.text = [NSString stringWithFormat:@"网页由\"%@\"提供.", host ? host : bundle];
}

/// 网页开始加载
- (void)cl_webViewDidStartLoad{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    self.backgroundLabel.text = @"正在加载...";
    self.navigationItem.title = @"正在加载...";
}

///主页数据加载发生错误
- (void)cl_didFailLoadWithError:(NSError *)error{
    if (error.code == NSURLErrorCannotFindHost) {// 404
        [self loadURL:[NSURL fileURLWithPath:kCL404NotFoundHTMLPath]];
    } else {
        [self loadURL:[NSURL fileURLWithPath:kCLNetworkErrorHTMLPath]];
    }
    self.backgroundLabel.text = [NSString stringWithFormat:@"%@%@",@"加载失败", error.localizedDescription];
    self.navigationItem.title = @"加载失败";
    [self updateNavigationItems];
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [self.progressView setProgress:0.9 animated:YES];
}

#pragma mark - KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"scrollView.contentOffset"]) {
        // Get the current content offset.
        CGPoint contentOffset = [change[NSKeyValueChangeNewKey] CGPointValue];
        self.backgroundLabel.transform = CGAffineTransformMakeTranslation(0, -contentOffset.y);
    } else if ([keyPath isEqualToString:@"estimatedProgress"]) {
        float progress = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
        if (progress >= self.progressView.progress) {
            [self.progressView setProgress:progress animated:YES];
        } else {
            [self.progressView setProgress:progress animated:NO];
        }
        if (progress == 1.0) {
            ///当进度条为1加载完成的时候隐藏进度条，并且要更新导航条按钮
            [self.progressView setProgress:0.0 animated:NO];
            self.progressView.hidden = YES;
            [self updateNavigationItems];
        }else{
            self.progressView.hidden = NO;
        }
    } else if ([keyPath isEqualToString:@"title"]) {
        [self updateTitleOfWebVC];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - WKUIDelegate

- (nullable WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {
    WKFrameInfo *frameInfo = navigationAction.targetFrame;
    if (![frameInfo isMainFrame]) {
        if (navigationAction.request) {
            [webView loadRequest:navigationAction.request];
        }
    }
    return nil;
}

///JavaScript调用alert方法后回调的方法 message中为alert提示的信息 必须要在其中调用completionHandler()
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
    // Get host name of url.
    NSString *host = webView.URL.host;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:host?:@"提示" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        if (completionHandler != NULL) {
            completionHandler();
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action){
        if (completionHandler != NULL) {
            completionHandler();
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

///JavaScript调用confirm方法后回调的方法 confirm是js中的确定框，需要在block中把用户选择的情况传递进去
- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL result))completionHandler {
    // Get the host name.
    NSString *host = webView.URL.host;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:host?:@"提示" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        if (completionHandler != NULL) {
            completionHandler(YES);
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action){
        if (completionHandler != NULL) {
            completionHandler(NO);
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

///JavaScript调用prompt方法后回调的方法 prompt是js中的输入框 需要在block中把用户输入的信息传入
- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(nullable NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * __nullable result))completionHandler {
    // Get the host of url.
    NSString *host = webView.URL.host;

    UIAlertController* alert = [UIAlertController alertControllerWithTitle:prompt?:@"提示" message:host preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = defaultText?:@"请输入";
        textField.font = [UIFont systemFontOfSize:12];
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [alert dismissViewControllerAnimated:YES completion:NULL];
        NSString *string = [alert.textFields firstObject].text;
        if (completionHandler != NULL) {
            completionHandler(string?:defaultText);
        }
    }];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [alert dismissViewControllerAnimated:YES completion:NULL];
        NSString *string = [alert.textFields firstObject].text;
        if (completionHandler != NULL) {
            completionHandler(string?:defaultText);
        }
    }];
    [alert addAction:cancelAction];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:NULL];
}

#pragma -mark WKNavigationDelegate
/////========================以下方法按顺序调用==========================///
///webview跳转之前调用，可以根据navigationAction决定是否要进行跳转，即webview是否需要加载新的request。
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSLog(@"1");
    // Disable all the '_blank' target in page's target.
    if (!navigationAction.targetFrame.isMainFrame) {
        [webView evaluateJavaScript:@"var a = document.getElementsByTagName('a');for(var i=0;i<a.length;i++){a[i].setAttribute('target','');}" completionHandler:nil];
    }

    NSURLComponents *components = [[NSURLComponents alloc] initWithString:navigationAction.request.URL.absoluteString];
    if ([[NSPredicate predicateWithFormat:@"SELF BEGINSWITH[cd] 'https://itunes.apple.com/' OR SELF BEGINSWITH[cd] 'mailto:' OR SELF BEGINSWITH[cd] 'tel:' OR SELF BEGINSWITH[cd] 'telprompt:'"] evaluateWithObject:components.URL.absoluteString]) {
        // 监测到AppStore的链接自动跳转到AppStore
        if ([[NSPredicate predicateWithFormat:@"SELF BEGINSWITH[cd] 'https://itunes.apple.com/'"] evaluateWithObject:components.URL.absoluteString]) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:@"即将前往AppStore" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"前往" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
                if (@available(iOS 10.0, *)) {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[components.URL.absoluteString stringByReplacingOccurrencesOfString:@"https" withString:@"itms-apps"]] options:@{} completionHandler:NULL];
                }else{
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[components.URL.absoluteString stringByReplacingOccurrencesOfString:@"https" withString:@"itms-apps"]]];
                }
            }]];
            [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action){

            }]];
            [self presentViewController:alert animated:YES completion:nil];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        }
        // 监测到拨打电话或者发邮件
        if ([[UIApplication sharedApplication] canOpenURL:components.URL]) {
            if (@available(iOS 10.0, *)) {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:components.URL.absoluteString] options:@{} completionHandler:NULL];
            }else{
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:components.URL.absoluteString]];
            }
        }
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    } else if (![[NSPredicate predicateWithFormat:@"SELF MATCHES[cd] 'https' OR SELF MATCHES[cd] 'http' OR SELF MATCHES[cd] 'file' OR SELF MATCHES[cd] 'about'"] evaluateWithObject:components.scheme]) {// For any other schema but not `https`、`http` and `file`.
        if ([[UIApplication sharedApplication] canOpenURL:components.URL]) {
            if (@available(iOS 10.0, *)) {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:components.URL.absoluteString] options:@{} completionHandler:NULL];
            }else{
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:components.URL.absoluteString]];
            }
        }
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }

    // URL actions for 404 and Errors:
    if ([[NSPredicate predicateWithFormat:@"SELF ENDSWITH[cd] %@ OR SELF ENDSWITH[cd] %@", kCL404NotFoundURLKey, kCLNetworkErrorURLKey] evaluateWithObject:components.URL.absoluteString]) {
        // Reload the original URL.
        [self loadURL:_url];
    }
    //更新导航条按钮
    [self updateNavigationItems];
    decisionHandler(WKNavigationActionPolicyAllow);
}

///webview开始加载新页面时调用此方法，该方法调用时页面还没有变化
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation {
    [self cl_webViewDidStartLoad];
    NSLog(@"2");
}

///webview在获取到页面返回信息后决定是否跳转的代理方法。如果此时decisionHandler(WKNavigationResponsePolicyCancel),则webview不加载新的请求，不显示新的界面。
- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    decisionHandler(WKNavigationResponsePolicyAllow);
    NSLog(@"3");
}

//当主机接收到的服务重定向时调用
-(void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(WKNavigation *)navigation{
    NSLog(@"4");
}

//主页数据加载发生错误时调用
-(void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(nonnull NSError *)error{
    NSLog(@"5");
    if (error.code == NSURLErrorCancelled) {
        return;
    }
    [self cl_didFailLoadWithError:error];
    
}

///// 需要响应身份验证时调用 同样在block中需要传入用户身份凭证
//- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *__nullable credential))completionHandler {
//
//}

///webview开始加载新页面时调用此方法，当进入新页面（显示新页面）时，此方法被调用
- (void)webView:(WKWebView *)webView didCommitNavigation:(null_unspecified WKNavigation *)navigation {
     NSLog(@"6");
}

///webView新页面加载完成，页面元素完全显示后调用此方法。
- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation {
    [self cl_webViewDidFinishLoad];
     NSLog(@"7");
}

- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error{
     NSLog(@"8");
}

#pragma -mark setter and getters

- (WKWebView *)webView{
    if (!_webView) {
        _webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height) configuration:[self getConfiguration]];
        //是否允许右滑返回手势
        _webView.allowsBackForwardNavigationGestures = YES;
        _webView.backgroundColor = [UIColor clearColor];
        _webView.scrollView.backgroundColor = [UIColor clearColor];
        // Set auto layout enabled.设置为NO使用auto layout，为YES不使用auto layout
        _webView.translatesAutoresizingMaskIntoConstraints = YES;
        _webView.UIDelegate = self;
        _webView.navigationDelegate = self;
    
        [_webView addObserver:self forKeyPath:@"scrollView.contentOffset" options:NSKeyValueObservingOptionNew context:NULL];
        [_webView addObserver:self forKeyPath:@"title" options:NSKeyValueObservingOptionNew context:NULL];
        [_webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:NULL];
    }
    return _webView;
}

///关于默认WKWebViewConfiguration的一些配置
- (WKWebViewConfiguration *)getConfiguration{
    if (!_configuration) {
        _configuration = [[WKWebViewConfiguration alloc] init];
        _configuration.preferences.minimumFontSize = 9.0;
        _configuration.preferences.javaScriptEnabled = YES;
        _configuration.preferences.javaScriptCanOpenWindowsAutomatically = NO;
        //HTML5 videos是否在页面内播放，为NO则用原生播放器播放
        if ([_configuration respondsToSelector:@selector(setAllowsInlineMediaPlayback:)]) {
            [_configuration setAllowsInlineMediaPlayback:YES];
        }
        if (@available(iOS 9.0, *)) {
            //设置请求的User-Agent信息中应用程序名称
            if ([_configuration respondsToSelector:@selector(setApplicationNameForUserAgent:)]) {
                
                [_configuration setApplicationNameForUserAgent:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"]];
            }
        } else {
            // Fallback on earlier versions
        }
        
        if (@available(iOS 10.0, *)) {
            //当选择WKAudiovisualMediaTypeNone的时候, 表示音视频的播放不需要用户手势触发, 即为自动播放
            if ([_configuration respondsToSelector:@selector(setMediaTypesRequiringUserActionForPlayback:)]){
                [_configuration setMediaTypesRequiringUserActionForPlayback:WKAudiovisualMediaTypeNone];
            }
        } else if (@available(iOS 9.0, *)) {
            //设置视频是否需要用户手动播放  设置为NO则会允许自动播放
            if ( [_configuration respondsToSelector:@selector(setRequiresUserActionForMediaPlayback:)]) {
                [_configuration setRequiresUserActionForMediaPlayback:NO];
            }
            //设置是否允许画中画技术 在特定设备上有效
            if ([_configuration respondsToSelector:@selector(setAllowsAirPlayForMediaPlayback:)]) {
                [_configuration setAllowsAirPlayForMediaPlayback:YES];
            }
        } else {
            //当mediaPlaybackRequiresUserAction这个属性设置为NO的时候, 就是自动播放, 不需要用户采取任何手势开启播放
            if ( [_configuration respondsToSelector:@selector(setMediaPlaybackRequiresUserAction:)]) {
                [_configuration setMediaPlaybackRequiresUserAction:NO];
            }
        }
    }
    return _configuration;
}

- (UIView *)containerView{
    if (!_containerView) {
        _containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height)];
        _containerView.backgroundColor = [UIColor redColor];
    }
    return _containerView;
}

- (UILabel *)backgroundLabel{
    if (!_backgroundLabel) {
        _backgroundLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, -30, self.view.bounds.size.width, 20)];
        _backgroundLabel.font = [UIFont systemFontOfSize:12];
        _backgroundLabel.numberOfLines = 0;
        _backgroundLabel.textAlignment = NSTextAlignmentCenter;
        _backgroundLabel.backgroundColor = [UIColor clearColor];
        _backgroundLabel.textColor = [UIColor blackColor];
    }
    return _backgroundLabel;
}

- (UIProgressView *)progressView {
    if (!_progressView){
        CGFloat progressBarHeight = 2.0f;
        CGRect navigationBarBounds = self.navigationController.navigationBar.bounds;
        CGRect barFrame = CGRectMake(0, navigationBarBounds.size.height - progressBarHeight, navigationBarBounds.size.width, progressBarHeight);
        _progressView = [[UIProgressView alloc] initWithFrame:barFrame];
        _progressView.trackTintColor = [UIColor clearColor];
        _progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    }
    return _progressView;
}

///返回上一页
- (UIBarButtonItem *)navigationBackBarButtonItem {
    if (!_navigationBackBarButtonItem) {
        NSString *bundlePath = [[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:@"CLWebViewImage.bundle"];
        NSString *img_path = [bundlePath stringByAppendingPathComponent:@"nav_back_icon"];
        UIImage* backItemImage = [[[UINavigationBar appearance] backIndicatorImage] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]?:[[UIImage imageWithContentsOfFile:img_path]  imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        UIImage* backItemHlImage = newImage?:[[UIImage imageWithContentsOfFile:img_path] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        UIButton* backButton = [UIButton buttonWithType:UIButtonTypeSystem];
        NSDictionary *attr = [[UIBarButtonItem appearance] titleTextAttributesForState:UIControlStateNormal];
        NSString *backBarButtonItemTitleString = @"返回";
        if (attr) {
            [backButton setAttributedTitle:[[NSAttributedString alloc] initWithString:backBarButtonItemTitleString attributes:attr] forState:UIControlStateNormal];
            UIOffset offset = [[UIBarButtonItem appearance] backButtonTitlePositionAdjustmentForBarMetrics:UIBarMetricsDefault];
            backButton.titleEdgeInsets = UIEdgeInsetsMake(offset.vertical, offset.horizontal, 0, 0);
            backButton.imageEdgeInsets = UIEdgeInsetsMake(offset.vertical, offset.horizontal, 0, 0);
        } else {
            [backButton setTitle:backBarButtonItemTitleString forState:UIControlStateNormal];
            [backButton setTitleColor:self.navigationController.navigationBar.tintColor forState:UIControlStateNormal];
            [backButton setTitleColor:[self.navigationController.navigationBar.tintColor colorWithAlphaComponent:0.5] forState:UIControlStateHighlighted];
            [backButton.titleLabel setFont:[UIFont systemFontOfSize:17]];
        }
        [backButton setImage:backItemImage forState:UIControlStateNormal];
        [backButton setImage:backItemHlImage forState:UIControlStateHighlighted];
        [backButton sizeToFit];
        if (@available(iOS 11.0, *)) {
            backButton.contentHorizontalAlignment =UIControlContentHorizontalAlignmentLeft;
            [backButton setImageEdgeInsets:UIEdgeInsetsMake(0,-12 *self.view.frame.size.width /375.0,0, 0)];
            [backButton setTitleEdgeInsets:UIEdgeInsetsMake(0,-12 *self.view.frame.size.width /375.0,0, 0)];
        }
        
        [backButton addTarget:self action:@selector(navigationItemHandleBack:) forControlEvents:UIControlEventTouchUpInside];
        _navigationBackBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];
    }
    return _navigationBackBarButtonItem;
}

///关闭按钮
- (UIBarButtonItem *)navigationCloseBarButtonItem {
    if (!_navigationCloseBarButtonItem) {
        _navigationCloseBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:0 target:self action:@selector(navigationIemHandleClose:)];
    }
    return _navigationCloseBarButtonItem;
}

@end



