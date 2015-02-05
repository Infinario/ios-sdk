//
//  CommandManager.m
//  InfinarioSDK
//
//  Created by Igi on 2/5/15.
//  Copyright (c) 2015 Infinario. All rights reserved.
//

#import "CommandManager.h"
#import "DbQueue.h"
#import "Http.h"

int const MAX_RETRIES = 50;

@interface CommandManager ()

@property DbQueue *dbQueue;
@property Http *http;

@end

@implementation CommandManager

- (instancetype)initWithTarget:(NSString *)target {
    self = [super init];
    
    self.dbQueue = [[DbQueue alloc] init];
    self.http = [[Http alloc] initWithTarget: target];
    
    return self;
}

- (void)schedule:(Command *)command {
    [self.dbQueue schedule:[command getPayload]];
}

- (void)flush {
    int retries = MAX_RETRIES;
    
    while (retries > 0) {
        if (![self executeBatch]) {
            if ([self.dbQueue isEmpty]) {
                break;
            }
            else {
                retries--;
            }
        }
    }
}

- (NSNumber *)nowInSeconds {
    return [NSNumber numberWithLong:[[NSDate date] timeIntervalSince1970]];
}

- (void)setAge:(NSMutableDictionary *)command {
    if (command[@"data"] && command[@"data"][@"age"]) {
        command[@"data"][@"age"] = [NSNumber numberWithLong:[[self nowInSeconds] longValue] - [command[@"data"][@"age"] longValue]];
    }
}

- (BOOL)executeBatch {
    NSMutableSet *successful = [[NSMutableSet alloc] init];
    NSMutableSet *failed = [[NSMutableSet alloc] init];
    NSArray *requests = [self.dbQueue pop];
    NSMutableArray *commands = [[NSMutableArray alloc] init];
    NSMutableDictionary *request;
    NSDictionary *result;
    NSString *status;
    
    if (![requests count]) return NO;
    
    for (NSDictionary *req in requests) {
        [self setAge:req[@"command"]];
        [commands addObject:req[@"command"]];
        [failed addObject:req[@"id"]];
    }
    
    NSDictionary *response = [self.http post:@"bulk" withPayload:@{@"commands": commands}];
    
    if (response && response[@"results"]) {
        for (int i = 0; i < [response[@"results"] count] && i < [requests count]; ++i) {
            request = requests[i];
            result = response[@"results"][i];
            status = [result[@"status"] lowercaseString];
            
            if ([status isEqualToString:@"ok"]) {
                [failed removeObject:request[@"id"]];
                [successful addObject:request[@"id"]];
            }
            else if ([status isEqualToString:@"retry"]) {
                [failed removeObject:request[@"id"]];
            }
        }
    }
    
    [self.dbQueue clear:[successful allObjects] andFailed:[failed allObjects]];
    
    NSLog(@"Sent commands: %d successful, %d failed out of %d", (int) [successful count], (int) [failed count], (int) [requests count]);
    
    return [successful count] > 0 || [failed count] > 0;
}

@end
