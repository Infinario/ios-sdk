//
//  Infinario.m
//  InfinarioSDK
//
//  Created by Igi on 2/4/15.
//  Copyright (c) 2015 Infinario. All rights reserved.
//

#import "Infinario.h"
#import "Preferences.h"
#import "Customer.h"
#import "Event.h"
#import "CommandManager.h"

@interface Infinario ()

@property NSString *token;
@property NSString *target;
@property NSDictionary *customer;
@property CommandManager *commandManager;
@property Preferences *preferences;
@property BOOL identified;

@end

@implementation Infinario

- (instancetype)initWithToken:(NSString *)token andWithTarget:(NSString *)target andWithCustomer:(NSMutableDictionary *)customer {
    self = [super init];
    
    self.token = token;
    self.target = target ? target : @"https://api.infinario.com";
    self.identified = NO;
    
    self.commandManager = [[CommandManager alloc] initWithTarget:target];
    self.preferences = [[Preferences alloc] init];
    
    if (customer) [self identifyWithCustomerDict:customer];
    
    return self;
}

+ (id)sharedInstanceWithToken:(NSString *)token andWithTarget:(NSString *)target andWithCustomerDict:(NSMutableDictionary *)customer {
    static dispatch_once_t p = 0;
    
    __strong static id _sharedObject = nil;
    
    dispatch_once(&p, ^{
        _sharedObject = [[self alloc] initWithToken:token andWithTarget:target andWithCustomer:customer];
    });
    
    return _sharedObject;
}

+ (id)sharedInstanceWithToken:(NSString *)token andWithTarget:(NSString *)target andWithCustomer:(NSString *)customer {
    return [self sharedInstanceWithToken:token andWithTarget:target andWithCustomerDict:[self customerDict:customer]];
}

+ (id)sharedInstanceWithToken:(NSString *)token andWithTarget:(NSString *)target {
    return [self sharedInstanceWithToken:token andWithTarget:target andWithCustomerDict:nil];
}

+ (id)sharedInstanceWithToken:(NSString *)token andWithCustomerDict:(NSMutableDictionary *)customer {
    return [self sharedInstanceWithToken:token andWithTarget:nil andWithCustomerDict:customer];
}

+ (id)sharedInstanceWithToken:(NSString *)token andWithCustomer:(NSString *)customer {
    return [self sharedInstanceWithToken:token andWithTarget:nil andWithCustomerDict:[self customerDict:customer]];
}

+ (id)sharedInstanceWithToken:(NSString *)token {
    return [self sharedInstanceWithToken:token andWithTarget:nil andWithCustomerDict:nil];
}

+ (NSMutableDictionary *)customerDict:(NSString *)customer {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    
    if (customer) {
        dict[@"registered"] = customer;
    }
    
    return dict;
}

- (void)identifyWithCustomerDict:(NSMutableDictionary *)customer andUpdate:(NSDictionary *)properties {
    if (!(customer[@"cookie"] && [customer[@"cookie"] length])) {
        customer[@"cookie"] = [self getCookie];
    }
    
    self.customer = customer;
    self.identified = YES;
    
    if (properties) [self update:properties];
}

- (void)identifyWithCustomer:(NSString *)customer andUpdate:(NSDictionary *)properties {
    [self identifyWithCustomerDict:[[self class] customerDict:customer] andUpdate:properties];
}

- (void)identifyWithCustomerDict:(NSMutableDictionary *)customer {
    [self identifyWithCustomerDict:customer andUpdate:nil];
}

- (void)identifyWithCustomer:(NSString *)customer {
    [self identifyWithCustomer:customer andUpdate:nil];
}

- (void)update:(NSDictionary *)properties {
    if (!self.identified) [self identifyWithCustomer:nil];
    
    Customer *customer = [[Customer alloc] initWithIds:self.customer andProjectId:self.token andWithProperties:properties];
    
    [self.commandManager schedule:customer];
    
    // TODO: handle automatic flushing;
}

- (void)track:(NSString *)type withProperties:(NSDictionary *)properties withTimestamp:(NSNumber *)timestamp {
    if (!self.identified) [self identifyWithCustomer:nil];
    
    Event *event = [[Event alloc] initWithIds:self.customer andProjectId:self.token andWithType:type andWithProperties:properties andWithTimestamp:timestamp];
    
    [self.commandManager schedule:event];
    
    // TODO: handle automatic flushing;
}

- (void)track:(NSString *)type withProperties:(NSDictionary *)properties {
    [self track:type withProperties:properties withTimestamp:nil];
}

- (void)track:(NSString *)type withTimestamp:(NSNumber *)timestamp {
    [self track:type withProperties:nil withTimestamp:timestamp];
}

- (void)track:(NSString *)type {
    [self track:type withProperties:nil withTimestamp:nil];
}

- (void)flush {
    // TODO: handle background task;
    [self.commandManager flush];
}

- (NSString *)getCookie {
    NSString *cookie = [self.preferences objectForKey:@"cookie"];
    
    if (!cookie) {
        CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
        cookie = (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
        CFRelease(uuid);
        
        [self.preferences setObject:cookie forKey:@"cookie"];
    }
    
    return cookie;
}

- (void)test {
    NSLog(@"vypise nieco z infinario classy");
    
    Preferences *prefs = [[Preferences alloc] init];
    CommandManager *commandManager = [[CommandManager alloc] initWithTarget:@"http://10.0.1.58:5001"];
    
    NSString *cookie = [prefs objectForKey:@"cookie"];
    NSLog(@"Cookie: %@", cookie);
    
    [prefs setObject:@"haluz" forKey:@"cookie"];
    
    NSString *projectId = @"b7746130-a22d-11e4-878d-ac9e17ec6d2c";
    
    Event *e = [[Event alloc] initWithIds:@{@"cookie": @"jyufuh"} andProjectId:projectId andWithType:@"iostest" andWithProperties:@{@"a":@1} andWithTimestamp:@(86400*4)];
    
    [commandManager schedule:e];
    [commandManager flush];
}

@end
