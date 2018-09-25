//
//  CLWebViewController.h
//  Labor
//
//  Created by Apple on 2018/4/3.
//  Copyright © 2018年 chilim. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

@interface CLWebViewController : UIViewController

/**
 webView
 */
@property (nonatomic, strong) WKWebView *webView;

/**
 加载的url
 */
@property (nonatomic, strong, readonly) NSURL *url;

/**
 要加载的request
 */
@property (nonatomic, strong) NSMutableURLRequest *request;

/**
 加载超时时间
 */
@property (nonatomic, assign) NSTimeInterval timeout;

/**
 是否需要清理webview缓存,默认为NO
 */
@property (nonatomic, assign) BOOL isClearWebCache;

/**
 初始化方法

 @param urlString 以http或https开头的url字符串
 @return 返回controller实例
 */
- (instancetype)initWithAddress:(NSString *)urlString;

/**
 初始化方法

 @param url 以http或https开头的url
 @return 返回controller实例
 */
- (instancetype)initWithURL:(NSURL*)url;

/**
 初始化方法

 @param url 以http或https开头的url
 @param configuration 自定义的WKWebViewConfiguration
 @return 返回controller实例
 */
- (instancetype)initWithURL:(NSURL *)url configuration:(WKWebViewConfiguration *)configuration;

/**
 初始化方法

 @param urlString 以http或https开头的url字符串
 @param configuration 自定义的WKWebViewConfiguration
 @return 返回controller实例
 */
- (instancetype)initWithAddress:(NSString *)urlString configuration:(WKWebViewConfiguration *)configuration;

/**
 webview加载完成之后的回调
 */
- (void)cl_webViewDidFinishLoad;

/**
 清理缓存

 @param completion 清理缓存完成后的回调
 */
+ (void)clearWebCacheCompletion:(dispatch_block_t)completion;

@end


