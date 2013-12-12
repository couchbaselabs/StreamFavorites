//
//  CBLIUpdate.h
//  StreamFavorites
//
//  Created by Chris Anderson on 12/11/13.
//  Copyright (c) 2013 Chris Anderson. All rights reserved.
//

#import <CouchbaseLite/CouchbaseLite.h>

@interface CBLIUpdate : CBLModel

@property (readwrite) bool favorite;
@property (readwrite) NSString* userID;

-(NSString*) headline;
-(NSString*) url;

+ (CBLQuery*) queryRecentFavoritesInDatabase: (CBLDatabase*)db;
+ (CBLQuery*) queryRecentUpdatesInDatabase: (CBLDatabase*)db;
+ (NSNumber*) maximumTimestampInDatabase: (CBLDatabase*)db;
@end
