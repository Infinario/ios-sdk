//
//  Device.m
//  InfinarioSDK
//
//  Created by Igi on 3/12/15.
//  Copyright (c) 2015 Infinario. All rights reserved.
//

#import "Device.h"
#import "Infinario.h"

@implementation Device

NSString * const SDK = @"iOS SDK";
NSString * const SDK_VERSION = @"1.0.5";
NSString * const OS = @"iOS";

+ (NSMutableDictionary *)deviceProperties {
    NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
    
    properties[@"sdk"] = SDK;
    properties[@"sdk_version"] = SDK_VERSION;
    properties[@"os_name"] = OS;
    properties[@"os_version"] = [[UIDevice currentDevice] systemVersion];
    properties[@"device_model"] = [[UIDevice currentDevice] model];
    
    return properties;
}

@end
