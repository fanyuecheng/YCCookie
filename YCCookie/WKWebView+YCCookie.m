//
//  WKWebView+YCCookie.m
//  YCCookie
//
//  Created by 月成 on 2019/11/1.
//

#import "WKWebView+YCCookie.h"
#import <objc/runtime.h>

@implementation WKWebView (YCCookie)

static const void * kCookieDelegateKey = &"kCookieDelegateKey";

- (void)setCookieDelegate:(id<YCWkWebViewCookieDelegate>)cookieDelegate {
    objc_setAssociatedObject(self, kCookieDelegateKey, cookieDelegate, OBJC_ASSOCIATION_ASSIGN);
}

- (id<YCWkWebViewCookieDelegate>)cookieDelegate {
    return objc_getAssociatedObject(self, kCookieDelegateKey);
}

static const void * kCustomCookiesKey = &"kCustomCookiesKey";
 
- (void)setCustomCookies:(NSArray *)customCookies {
    objc_setAssociatedObject(self, kCustomCookiesKey, customCookies, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray *)customCookies {
    return objc_getAssociatedObject(self, kCustomCookiesKey);
}

#pragma mark - Method

#define kYCCookieJsCodeTag @"// 这是一个标识，用于删除某个WKUserScript代码片段的标记"

- (void)setupCustomCookie {
    [self addCookieScript];
    [self reloadCookie];
}

/// 设置 App 基本支持的JS代码
- (void)addCookieScript {
    NSURL *resourceURL = [[NSBundle mainBundle] URLForResource:@"YCCookie" withExtension:@"js"];
    NSData *resourceData = [NSData dataWithContentsOfURL:resourceURL];
    NSString *jsCode = [[NSString alloc] initWithData:resourceData encoding:NSUTF8StringEncoding];
 
    if (jsCode) {
        WKUserScript *cookieInScript = [[WKUserScript alloc]
                                        initWithSource:jsCode
                                        injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                        forMainFrameOnly:NO];
        [self.configuration.userContentController addUserScript:cookieInScript];
    }
}

/// 刷新设置cookie
- (void)reloadCookie {
    [self removeAllTagCookie];
    
    // 代理获取最新的cookie值
    if (self.cookieDelegate && [self.cookieDelegate respondsToSelector:@selector(webviewCookies)]) {
        self.customCookies = [self.cookieDelegate webviewCookies];
    }

    //重新添加cookie
    if (self.customCookies.count) {
        if (@available(iOS 11, *)) {
            WKHTTPCookieStore *cookieStore = [WKWebsiteDataStore defaultDataStore].httpCookieStore;
            
            for (NSHTTPCookie *cookie in self.customCookies) {
                [cookieStore setCookie:cookie completionHandler:nil];
            }
        } else {
            for (NSHTTPCookie *cookie in self.customCookies) {
                [self addCookieWithKey:cookie.name
                                 value:cookie.value];
            }
        }
    }
}

///添加某个cookie
- (void)addCookieWithKey:(NSString *)key value:(NSString *)value {
    NSString *jsCode = [NSString stringWithFormat:@"app_setCookie('%@','%@')", key, value];
    [self evaluateJavaScript:jsCode completionHandler:nil];
    
    // 代码片段标签
    NSString *tag = [self getCustomJsCodeTagWithKey:key];
    
    // 先删除原来的代码片段
    [self deleteUserSciptWithTag:tag];
    
    // 再添加新的
    [self addUserScriptWithJsCode:jsCode WithTag:tag];
}

/// 删除某个cookie
- (void)removeCookieWithName:(NSString *)name {
    if (@available(iOS 11, *)) {
        WKHTTPCookieStore *httpCookieStore = [WKWebsiteDataStore defaultDataStore].httpCookieStore;
        
        [httpCookieStore getAllCookies:^(NSArray<NSHTTPCookie *> * _Nonnull cookies) {
            for (NSHTTPCookie *cookie in cookies) {
                if ([cookie.name isEqualToString:name]) {
                    [httpCookieStore deleteCookie:cookie completionHandler:nil];
                    break;
                }
            }
        }];
    } else {
        // 删除浏览器的某个cookie
        NSString *jsCode = [NSString stringWithFormat:@"app_deleteCookie('%@')", name];
        [self evaluateJavaScript:jsCode completionHandler:nil];
        
        // 删除添加cookie的脚本代码
        NSString *tag = [self getCustomJsCodeTagWithKey:name];
        [self deleteUserSciptWithTag:tag];
    }
}

/// 删除所有的标签（app自定义）cookie
- (void)removeAllTagCookie {
    // 删除所有的cookie
    if (self.customCookies.count) {
        if (@available(iOS 11, *)) {
            WKHTTPCookieStore *httpCookieStore = [WKWebsiteDataStore defaultDataStore].httpCookieStore;
            for (NSHTTPCookie *cookie in self.customCookies) {
                [httpCookieStore deleteCookie:cookie completionHandler:nil];
            }
        } else {
            for (NSHTTPCookie *cookie in self.customCookies) {
                NSString *jsCode = [NSString stringWithFormat:@"app_deleteCookie('%@')", cookie.name];
                [self evaluateJavaScript:jsCode completionHandler:nil];
            }
        }
    }
    
    // 删除所有的本地自定义js 设置cookie的脚本
    [self deleteUserSciptWithTag:[self getCustomJsCodeTagWithKey:nil]];
    
    // 属性置空
    self.customCookies = @[];
}

/// 添加某个代码片段
- (void)addUserScriptWithJsCode:(NSString *)jsCode WithTag:(NSString *)tag {
    if (jsCode) {
        WKUserScript *cookieInScript = [[WKUserScript alloc] initWithSource:[NSString stringWithFormat:@"%@ \n%@",jsCode,tag]
                                                              injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                           forMainFrameOnly:NO];
        [self.configuration.userContentController addUserScript:cookieInScript];
    }
}

/**
 删除某个代码片段
 
 @param tag 片段标示, （敲黑板）注意：当 tag == 宏定义 kJhuCookieJsCodeTag时，将删除所有的自定义cookie
 */
- (void)deleteUserSciptWithTag:(NSString *)tag {
    if (tag) {
        WKUserContentController *userContentController = self.configuration.userContentController;
        NSMutableArray<WKUserScript *> *array = [userContentController.userScripts mutableCopy];
        int i = 0;
        BOOL isHave = NO;
        for (WKUserScript *script in userContentController.userScripts) {
            if ([script.source containsString:tag]) {
                [array removeObjectAtIndex:i];
                isHave = YES;
                continue;
            }
            i ++;
        }
        
        // 如果原来的代码片段中存在
        if (isHave) {
            ///没法修改数组 只能移除全部 再重新添加
            [userContentController removeAllUserScripts];
            for (WKUserScript *script in array) {
                [userContentController addUserScript:script];
            }
        }
    }
}

/**
 自定义js脚本片段的一个标示，用于删除某段代码片段
 
 @param key cookie name
 @return 拼接后的代码片段标示
 */
- (NSString *)getCustomJsCodeTagWithKey:(NSString *)key {
    if (!key) key = @"";
    return [kYCCookieJsCodeTag stringByAppendingString:key];
}

- (NSString *)scriptString {
    return @"var app_cookieNames = document.cookie.split('; ').map( \
        function(cookie) { \
            return cookie.split('=')[0]; \
        } \
    ) \
    var app_rootDomain = ( \
        function() { \
            var rootDomain = document.domain; \
            ds =  {'com':'1','cn':'1','net':'1','org':'1', 'cc':'1', 'co':'1', 'top':'1', 'vip':'1', 'club':'1', 'info':'1'}; \
            arr = rootDomain.split('.'); \
            for(var i = arr.length - 1; i >= 0; i--) { \
                 if (isNaN(arr[i]) && !ds[arr[i]]) { \
                     break; \
                 } \
             } \
             if (i > 0) { \
                rootDomain = '.' + arr.slice(i).join('.'); \
             } \
             return rootDomain; \
        } () \
    ) \
    function app_setCookie(name, value) { \
        if (app_cookieNames.indexOf(name) == -1) { \
            document.cookie = name + '=' + value + ';domain=' + app_rootDomain + ';path=/'; \
        } \
    } \
    function app_deleteCookie(name) { \
        var date = new Date(); \
        date.setTime(date.getTime() -1); \
        document.cookie = name + '=;domain=' + app_rootDomain + ';expires=' + date.toGMTString() + ';path=/'; \
    } \
    ";
}

@end
