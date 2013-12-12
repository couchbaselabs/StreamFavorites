//
//  CBLIUpdate.m
//  StreamFavorites
//
//  Created by Chris Anderson on 12/11/13.
//  Copyright (c) 2013 Chris Anderson. All rights reserved.
//

#import "CBLIUpdate.h"

@implementation CBLIUpdate {
    
}
@dynamic favorite, userID;


+ (CBLQuery*) queryRecentFavoritesInDatabase: (CBLDatabase*)db {
    CBLView* view = [db viewNamed: @"favorites"];
    if (!view.mapBlock) {
        // Register the map function, the first time we access the view:
        [view setMapBlock: MAPBLOCK({
            if ( [doc[@"favorite"] boolValue]) {
                emit(doc[@"timestamp"], nil);
                NSLog(@"emit %@", doc[@"timestamp"]);
            }
        }) reduceBlock: nil version: @"11"]; // bump version any time you change the MAPBLOCK body!
    }
    CBLQuery * query = [view createQuery];
    query.descending = YES;
    return query;
}

+ (CBLQuery*) queryRecentUpdatesInDatabase: (CBLDatabase*)db {
    CBLView* view = [db viewNamed: @"updates"];
    if (!view.mapBlock) {
        // Register the map function, the first time we access the view:
        [view setMapBlock: MAPBLOCK({
            if (doc[@"updateType"])
                emit(doc[@"timestamp"], nil);
        }) reduceBlock: nil version: @"1"]; // bump version any time you change the MAPBLOCK body!
    }
    CBLQuery * query = [view createQuery];
    query.descending = YES;
    return query;
}

+ (NSNumber*) maximumTimestampInDatabase: (CBLDatabase*)db {
    CBLQuery *query = [self queryRecentUpdatesInDatabase:db];
    query.limit = 1;
    NSError *e;
    return [[[query rows:&e] nextRow] key];
}

-(NSString*) headline {
    return self.document.properties[@"updateContent"][@"person"][@"currentShare"][@"comment"];
}

-(NSString*) url {
    return self.document.properties[@"updateContent"][@"person"][@"currentShare"][@"content"][@"shortenedUrl"];
}

@end
