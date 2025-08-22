//
//  MRDLNADiagnostics.m
//  MRDLNA
//
//  Created by MRDLNA Team on 2025/8/22.
//

#import "MRDLNADiagnostics.h"
#import "CLUPnP.h"
#import <UIKit/UIKit.h>
#import <SystemConfiguration/SystemConfiguration.h>
#include <ifaddrs.h>
#include <arpa/inet.h>

@implementation MRDLNADiagnostics

+ (NSDictionary *)generateDiagnosticsReport {
    NSMutableDictionary *report = [NSMutableDictionary dictionary];
    
    // 系统信息
    report[@"device_info"] = @{
        @"model": [[UIDevice currentDevice] model],
        @"system_name": [[UIDevice currentDevice] systemName],
        @"system_version": [[UIDevice currentDevice] systemVersion],
        @"device_name": [[UIDevice currentDevice] name]
    };
    
    // 应用信息
    report[@"app_info"] = @{
        @"mrdlna_version": @"0.3.0",
        @"bundle_id": [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown"
    };
    
    // 网络信息
    report[@"network_info"] = [self getNetworkInfo];
    
    // 设备兼容性
    report[@"compatibility"] = @{
        @"ios_16_compatible": @([self checkiOS16Compatibility]),
        @"multicast_support": @([self checkMulticastSupport])
    };
    
    return [report copy];
}

+ (BOOL)checkDeviceCompatibility {
    // 检查iOS版本
    NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
    if (version.majorVersion < 12) {
        CLLog(@"设备兼容性检查: iOS版本过低 (%ld.%ld.%ld)", (long)version.majorVersion, (long)version.minorVersion, (long)version.patchVersion);
        return NO;
    }
    
    // 检查网络权限
    return [self checkNetworkPermissions];
}

+ (NSDictionary *)getNetworkInfo {
    NSMutableDictionary *networkInfo = [NSMutableDictionary dictionary];
    
    // 获取WiFi信息
    NSString *wifiIP = [self getWiFiIPAddress];
    if (wifiIP) {
        networkInfo[@"wifi_ip"] = wifiIP;
        networkInfo[@"wifi_connected"] = @YES;
    } else {
        networkInfo[@"wifi_connected"] = @NO;
    }
    
    // 检查组播支持
    networkInfo[@"multicast_support"] = @([self checkMulticastSupport]);
    
    return [networkInfo copy];
}

+ (void)printDebugInfo {
    NSDictionary *report = [self generateDiagnosticsReport];
    CLLog(@"=== MRDLNA 诊断报告 ===");
    CLLog(@"设备信息: %@", report[@"device_info"]);
    CLLog(@"网络信息: %@", report[@"network_info"]);
    CLLog(@"兼容性检查: %@", report[@"compatibility"]);
    CLLog(@"=== 诊断报告结束 ===");
}

#pragma mark - Private Methods

+ (BOOL)checkiOS16Compatibility {
    NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
    return version.majorVersion >= 16;
}

+ (BOOL)checkMulticastSupport {
    // 简单检查是否支持组播
    int sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) {
        return NO;
    }
    
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = inet_addr("239.255.255.250");
    addr.sin_port = htons(1900);
    
    int result = bind(sock, (struct sockaddr*)&addr, sizeof(addr));
    close(sock);
    
    return result == 0;
}

+ (BOOL)checkNetworkPermissions {
    // 检查基本的网络连接能力
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, "www.apple.com");
    if (!reachability) {
        return NO;
    }
    
    SCNetworkReachabilityFlags flags;
    BOOL success = SCNetworkReachabilityGetFlags(reachability, &flags);
    CFRelease(reachability);
    
    if (!success) {
        return NO;
    }
    
    BOOL isReachable = (flags & kSCNetworkReachabilityFlagsReachable) != 0;
    BOOL needsConnection = (flags & kSCNetworkReachabilityFlagsConnectionRequired) != 0;
    
    return isReachable && !needsConnection;
}

+ (NSString *)getWiFiIPAddress {
    NSString *address = nil;
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    
    success = getifaddrs(&interfaces);
    if (success == 0) {
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    
    freeifaddrs(interfaces);
    return address;
}

@end