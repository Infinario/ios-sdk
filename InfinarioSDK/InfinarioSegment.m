//
//  InfinarioSegment.m
//  InfinarioSDK
//
//  Created by Roland Rogansky on 07/09/15.
//  Copyright (c) 2015 Infinario. All rights reserved.
//

#import "InfinarioSegment.h"

@interface InfinarioSegment ()

@property NSString *name;

@end

@implementation InfinarioSegment

- (instancetype)initWithName:(NSString *)name {
    self = [super init];
    self.name = name;
    
    return self;
}

- (NSString *)getName {
    return self.name;
}

@end
