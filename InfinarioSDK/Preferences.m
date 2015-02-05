//
//  Preferences.m
//  InfinarioSDK
//
//  Created by Igi on 2/4/15.
//  Copyright (c) 2015 Infinario. All rights reserved.
//

#import "Preferences.h"

@interface Preferences ()

@property DbManager *dbManager;
@property NSMutableDictionary *prefs;

@end

@implementation Preferences

- (instancetype)init {
    self = [super init];
    
    self.dbManager = [[DbManager alloc] initWithDatabaseFilename: DB_FILE];
    [self createDbIfNecessary];
    
    self.prefs = [self load];
    
    return self;
}

- (id)objectForKey:(NSString *)key {
    return [self.prefs objectForKey:key];
}

- (void)setObject:(id)value forKey:(NSString *)key {
    [self.prefs setValue:value forKey:key];
    [self save:self.prefs];
}

- (NSMutableDictionary *)load {
    NSArray *prefsArray = [self.dbManager loadDataFromDb:@"SELECT * FROM preferences;"];
    NSMutableDictionary *prefs = [[NSMutableDictionary alloc] init];
    
    for (NSArray *option in prefsArray) {
        prefs[option[0]] = option[1];
    }
    
    return prefs;
}

- (void)save:(NSDictionary *)preferences {
    [self.dbManager executeQuery:@"DELETE FROM preferences;"];
    
    for (NSString *key in preferences) {
        [self.dbManager executeQuery:[NSString stringWithFormat:@"INSERT INTO preferences (key, value) VALUES ('%@', '%@')", key, preferences[key]]];
    }
}

- (void)createDbIfNecessary {
    [self.dbManager executeQuery:@"CREATE TABLE IF NOT EXISTS preferences ("
                                 " key TEXT PRIMARY KEY NOT NULL,"
                                 " value TEXT NOT NULL);"];
}

@end
