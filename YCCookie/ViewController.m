//
//  ViewController.m
//  YCCookie
//
//  Created by 月成 on 2019/11/1.
//

#import "ViewController.h"
#import "WKWebView+YCCookie.h"

@interface ViewController () <WKUIDelegate, WKNavigationDelegate, YCWkWebViewCookieDelegate>

@property (nonatomic, strong) WKWebView *webView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    NSString *str = @"var app_cookieNames = document.cookie.split('; ').map(\
    function(cookie) {\
    return cookie.split('=')[0];\
    }\
    )";
    
    NSLog(@"str==%@", str);
    
     
    self.view.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.webView];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://www.mihuashi.com"]];
    
    [self.webView loadRequest:request];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    CGRect bounds = self.view.bounds;

    CGFloat x = 0;
    CGFloat y = [UIApplication sharedApplication].statusBarFrame.size.height + self.navigationController.navigationBar.frame.size.height;
    CGFloat w = bounds.size.width;
    CGFloat h = bounds.size.height - y;
    
    if (@available(iOS 11, *)) {
        h -= self.view.safeAreaInsets.bottom;
    }
    
    self.webView.frame = CGRectMake(x, y, w, h);
}

#pragma mark - YCWkWebViewCookieDelegate
- (NSArray <NSHTTPCookie *> *)webviewCookies {
 
    NSDictionary *properties = @{NSHTTPCookieName : @"remember_token",
     NSHTTPCookieValue : @"EAh_EUPkrTF7VYZScu7ANw",
     NSHTTPCookieDomain : @"www.mihuashi.com",
     NSHTTPCookiePath : @"/"
    };
    
    return @[[NSHTTPCookie cookieWithProperties:properties]];
}

#pragma mark - WKNavigationDelegate
 
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    
    NSURLRequest *request = navigationAction.request;
    NSLog(@"HeaderFields==%@", request.allHTTPHeaderFields);
 
    decisionHandler(WKNavigationActionPolicyAllow);
}

#pragma mark - Get
- (WKWebView *)webView {
    if (!_webView) {
        _webView = [[WKWebView alloc] init];
        _webView.UIDelegate = self;
        _webView.navigationDelegate = self;
        _webView.cookieDelegate = self;
        [_webView setupCustomCookie];
    }
    return _webView;
}

@end
