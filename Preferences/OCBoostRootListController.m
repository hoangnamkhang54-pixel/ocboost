#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <Foundation/Foundation.h>
#import <math.h>
#import <stdint.h>

static NSString * const kOCBoostDomain = @"com.namkhangminhnguyen.ocboost";
static NSString * const kOCBoostChangedNotification = @"com.namkhangminhnguyen.ocboost/settingsChanged";

@interface OCBoostRootListController : PSListController
@end

@implementation OCBoostRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"OCBoost";
    self.view.tintColor = [UIColor colorWithRed:0.30 green:0.36 blue:0.96 alpha:1.0];
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    }
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = specifier.properties[@"key"];
    if (key.length == 0) return nil;

    CFPropertyListRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)key,
                                                        (__bridge CFStringRef)kOCBoostDomain);
    if (value) return CFBridgingRelease(value);
    return specifier.properties[@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = specifier.properties[@"key"];
    if (key.length == 0 || value == nil) return;

    CFPreferencesSetAppValue((__bridge CFStringRef)key,
                             (__bridge CFPropertyListRef)value,
                             (__bridge CFStringRef)kOCBoostDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)kOCBoostDomain);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)kOCBoostChangedNotification,
                                         NULL, NULL, true);
}

- (NSArray<NSString *> *)focusedBundleIDs {
    CFPropertyListRef value = CFPreferencesCopyAppValue(CFSTR("focusedBundleIDs"),
                                                        (__bridge CFStringRef)kOCBoostDomain);
    if (!value) return @[];
    id object = CFBridgingRelease(value);
    if (![object isKindOfClass:[NSArray class]]) return @[];
    NSMutableArray<NSString *> *items = [NSMutableArray array];
    for (id item in (NSArray *)object) {
        if ([item isKindOfClass:[NSString class]] && [item length] > 0) {
            [items addObject:item];
        }
    }
    return items;
}

- (void)postSettingsChanged {
    CFPreferencesAppSynchronize((__bridge CFStringRef)kOCBoostDomain);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)kOCBoostChangedNotification,
                                         NULL, NULL, true);
}

- (void)chooseFocusedApps {
    NSArray<NSString *> *current = [self focusedBundleIDs];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Ứng dụng ưu tiên"
                                                                   message:@"Nhập tối đa 5 Bundle ID, ngăn cách bằng dấu phẩy. Ví dụ TikTok: com.zhiliaoapp.musically"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"com.zhiliaoapp.musically, com.google.ios.youtube";
        field.text = [current componentsJoinedByString:@", "];
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Lưu" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action;
        NSString *raw = alert.textFields.firstObject.text ?: @"";
        NSArray<NSString *> *parts = [raw componentsSeparatedByString:@","];
        NSMutableOrderedSet<NSString *> *unique = [NSMutableOrderedSet orderedSet];
        for (NSString *part in parts) {
            NSString *item = [part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (item.length == 0) continue;
            [unique addObject:item];
        }
        if (unique.count > 5) {
            UIAlertController *error = [UIAlertController alertControllerWithTitle:@"Quá số lượng"
                                                                           message:@"OCBoost chỉ lưu tối đa 5 ứng dụng. Hãy bỏ bớt Bundle ID rồi thử lại."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [error addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [weakSelf presentViewController:error animated:YES completion:nil];
            return;
        }
        for (NSString *item in unique) {
            if ([item rangeOfString:@"."].location == NSNotFound || [item containsString:@" "]) {
                UIAlertController *error = [UIAlertController alertControllerWithTitle:@"Bundle ID chưa hợp lệ"
                                                                               message:[NSString stringWithFormat:@"Kiểm tra định dạng: %@", item]
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [error addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [weakSelf presentViewController:error animated:YES completion:nil];
                return;
            }
        }
        CFPreferencesSetAppValue(CFSTR("focusedBundleIDs"), (__bridge CFArrayRef)unique.array,
                                 (__bridge CFStringRef)kOCBoostDomain);
        [weakSelf postSettingsChanged];
        NSString *saved = unique.count ? [unique.array componentsJoinedByString:@"\n"] : @"Chưa chọn ứng dụng nào.";
        UIAlertController *done = [UIAlertController alertControllerWithTitle:@"Đã lưu danh sách"
                                                                      message:saved
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [done addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [weakSelf presentViewController:done animated:YES completion:nil];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)runCPUBenchmark {
    UIAlertController *waiting = [UIAlertController alertControllerWithTitle:@"Đang kiểm tra CPU…"
                                                                    message:@"OCBoost đang chạy một phép tính cục bộ ngắn."
                                                             preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:waiting animated:YES completion:nil];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        const uint64_t iterations = 400000;
        volatile double accumulator = 0.0;
        CFTimeInterval start = CACurrentMediaTime();
        for (uint64_t i = 1; i <= iterations; i++) {
            double x = (double)i * 0.00017;
            accumulator += sin(x) * cos(x * 0.73);
        }
        CFTimeInterval elapsed = CACurrentMediaTime() - start;
        double rate = elapsed > 0 ? ((double)iterations / elapsed) : 0;
        // Consume the result so the work cannot be trivially discarded.
        double finalValue = accumulator;
        dispatch_async(dispatch_get_main_queue(), ^{
            [waiting dismissViewControllerAnimated:YES completion:^{
                NSString *message = [NSString stringWithFormat:@"Thời gian: %.3f giây\nTốc độ: %.0f vòng/giây\nMã kiểm tra: %.4f\n\nĐiểm chỉ có ý nghĩa tham khảo trên chính thiết bị này.", elapsed, rate, finalValue];
                UIAlertController *result = [UIAlertController alertControllerWithTitle:@"CPU benchmark hoàn tất"
                                                                                 message:message
                                                                          preferredStyle:UIAlertControllerStyleAlert];
                [result addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:result animated:YES completion:nil];
            }];
        });
    });
}

- (void)runNetworkBenchmark {
    UIAlertController *waiting = [UIAlertController alertControllerWithTitle:@"Đang kiểm tra mạng…"
                                                                    message:@"Đang chạy tối đa 64 yêu cầu HTTPS song song (khoảng 4 MiB dữ liệu). Bài test không thay đổi cấu hình mạng."
                                                             preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:waiting animated:YES completion:nil];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        const NSInteger taskCount = 64;
        const NSUInteger bytesPerTask = 65536;
        dispatch_group_t group = dispatch_group_create();
        NSLock *lock = [[NSLock alloc] init];
        __block uint64_t receivedBytes = 0;
        __block NSInteger successes = 0;
        CFTimeInterval start = CACurrentMediaTime();

        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        configuration.timeoutIntervalForRequest = 15.0;
        configuration.timeoutIntervalForResource = 20.0;
        configuration.HTTPMaximumConnectionsPerHost = 64;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];

        for (NSInteger index = 0; index < taskCount; index++) {
            dispatch_group_enter(group);
            NSString *urlText = [NSString stringWithFormat:@"https://speed.cloudflare.com/__down?bytes=%lu&ocboost=%ld",
                                 (unsigned long)bytesPerTask, (long)index];
            NSURL *url = [NSURL URLWithString:urlText];
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
            request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
            NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                NSHTTPURLResponse *http = [response isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)response : nil;
                if (!error && http.statusCode >= 200 && http.statusCode < 300 && data.length > 0) {
                    [lock lock];
                    receivedBytes += data.length;
                    successes += 1;
                    [lock unlock];
                }
                dispatch_group_leave(group);
            }];
            [task resume];
        }

        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            CFTimeInterval elapsed = CACurrentMediaTime() - start;
            [session finishTasksAndInvalidate];
            [waiting dismissViewControllerAnimated:YES completion:^{
                double megabitsPerSecond = elapsed > 0 ? ((double)receivedBytes * 8.0 / elapsed / 1000000.0) : 0;
                NSString *message;
                if (successes == 0) {
                    message = @"Không nhận được dữ liệu thử nghiệm. Hãy kiểm tra kết nối Internet hoặc thử lại sau. Không có thay đổi nào được thực hiện lên cấu hình mạng.";
                } else {
                    message = [NSString stringWithFormat:@"Yêu cầu thành công: %ld/%ld\nDữ liệu nhận: %.2f MiB\nThời gian: %.2f giây\nThông lượng đo được: %.2f Mbps\n\nĐây là bài test 64 yêu cầu song song, không phải tính năng tăng tốc toàn hệ thống. Máy chủ/CDN có thể giới hạn tốc độ và số kết nối.", (long)successes, (long)taskCount, (double)receivedBytes / (1024.0 * 1024.0), elapsed, megabitsPerSecond];
                }
                UIAlertController *result = [UIAlertController alertControllerWithTitle:@"Network benchmark"
                                                                                 message:message
                                                                          preferredStyle:UIAlertControllerStyleAlert];
                [result addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:result animated:YES completion:nil];
            }];
        });
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    });
}

@end
