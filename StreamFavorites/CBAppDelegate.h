//
//  CBAppDelegate.h
//  StreamFavorites
//
//  Created by Chris Anderson on 12/9/13.
//  Copyright (c) 2013 Chris Anderson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CouchbaseLite/CouchbaseLite.h>
#import "CBLLinkedInAuth.h"

@interface CBAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) CBLDatabase *database;
@property (strong, nonatomic) CBLSyncManager *cblSync;

- (void) authForCBLSync: (void (^)())authenticated;
- (void) refreshStream;

@end
