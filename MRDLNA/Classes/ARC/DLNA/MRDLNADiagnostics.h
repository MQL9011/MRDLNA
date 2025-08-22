//
//  MRDLNADiagnostics.h
//  MRDLNA
//
//  Created by MRDLNA Team on 2025/8/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MRDLNADiagnostics : NSObject

/**
 生成诊断报告
 */
+ (NSDictionary *)generateDiagnosticsReport;

/**
 检查设备兼容性
 */
+ (BOOL)checkDeviceCompatibility;

/**
 获取网络信息
 */
+ (NSDictionary *)getNetworkInfo;

/**
 打印调试信息
 */
+ (void)printDebugInfo;

@end

NS_ASSUME_NONNULL_END