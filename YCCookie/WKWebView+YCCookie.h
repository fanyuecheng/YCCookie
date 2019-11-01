//
//  WKWebView+YCCookie.h
//  YCCookie
//
//  Created by 月成 on 2019/11/1.
//

#import <WebKit/WebKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol YCWkWebViewCookieDelegate <NSObject>

/// 获取传入cookie
- (NSArray <NSHTTPCookie *> *)webviewCookies;

@end

@interface WKWebView (YCCookie)

/// cookie代理
@property (nonatomic, weak) id <YCWkWebViewCookieDelegate> cookieDelegate;
/// 自定义 cookie 值
@property (nonatomic, copy) NSArray <NSHTTPCookie *> *customCookies;

/// 需要放到 loadRequest 之前
- (void)setupCustomCookie;

///刷新 cookie 
- (void)reloadCookie;

///删除 cookie
- (void)removeCookieWithName:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
