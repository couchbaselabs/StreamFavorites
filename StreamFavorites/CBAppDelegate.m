//
//  CBAppDelegate.m
//  StreamFavorites
//
//  Created by Chris Anderson on 12/9/13.
//  Copyright (c) 2013 Chris Anderson. All rights reserved.
//

#import "CBAppDelegate.h"
#import "AppSecretConfig.h"
#import "CBLIUpdate.h"

@implementation CBAppDelegate {
    BOOL refreshingStream;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    [self setupCBL];
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


#pragma mark - Setup Couchbase Lite and Linked-In Authentication

- (void) setupCBL {
    CBLManager *manager = [CBLManager sharedInstance];
    NSError *error;
    self.database = [manager databaseNamed: @"linkedin" error: &error];
    if (error) {
        NSLog(@"error getting database %@",error);
        exit(-1);
    }
//    set a filter on the sync so only favorites upload.
    
    NSURL *syncURL = [NSURL URLWithString:kSyncRemoteDB relativeToURL:[NSURL URLWithString:kSyncRemoteServer]];
    _cblSync = [[CBLSyncManager alloc] initSyncForDatabase:_database withURL:syncURL];
    // Tell the Sync Manager to use LinkedIn for login.
    _cblSync.authenticator = [[CBLLinkedInAuth alloc] initWithClientID:kLIClientID clientSecret:kLIClientSecret redirectURL:kLIRedirectURL grantedAccess:@[@"rw_nus"]];
    if (_cblSync.userID) {
        [_cblSync start];
    }
}

- (void) authForCBLSync: (void (^)())authenticated {
    // Application callback to create the user profile.
    // this will be triggered after we call [_cblSync start]
    [_cblSync beforeFirstSync:^(NSString *userID, NSDictionary *userData,  NSError **outError) {
        // This is a first run, setup the profile but don't save it yet.
        NSLog(@"about to sync");
        authenticated();
    }];
    [_cblSync start];
}

#pragma mark - LinkedIn data retrieval

// idealy this can happen continuously or on a schedule
// for now we trigger it when the view loads
- (void) refreshStream {
    NSLog(@"maybe refreshStream for %@", _cblSync.userID);

    if (!refreshingStream) {
        refreshingStream = YES;
        [self doRefreshStream];
    }
}
    
- (void) doRefreshStream {

    NSLog(@"refreshStream for %@", _cblSync.userID);
    if (_cblSync.userID) {
        CBLLinkedInAuth * auth = (CBLLinkedInAuth *)_cblSync.authenticator;
        LIALinkedInHttpClient *client = auth.client;
        NSString* accessToken = [[NSUserDefaults standardUserDefaults] objectForKey: @"LIaccessToken"];

        if (accessToken) {
            NSMutableDictionary *params = [@{@"oauth2_access_token": accessToken,
                                     @"format" : @"json",
                                     @"type" : @"SHAR",
                                     @"count" : @50} mutableCopy];
            
            NSNumber *after = [CBLIUpdate maximumTimestampInDatabase: _cblSync.database];
            if (after) {
                NSLog(@"paginating after=%@",after);
                params[@"after"] = after;
            }
            NSLog(@"getPath params %@", params);

            [client getPath:@"/v1/people/~/network/updates" parameters:params success:^(AFHTTPRequestOperation *operation, NSDictionary* streamData) {
                NSLog(@"Got stream %@", streamData);
                refreshingStream = NO;
                [self saveStreamData:streamData];
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                NSLog(@"Error getting stream %@", error);
                // reset access token
                NSLog(@"get accessToken");
                [self authForCBLSync:^{
                    [self doRefreshStream];
                }];
            }];
        } else {
            NSLog(@"get accessToken");
            [auth getCredentials:^(NSString *userID, NSDictionary *userData) {
                CBLLinkedInAuth * auth = (CBLLinkedInAuth *)_cblSync.authenticator;
                if (auth.accessToken) {
                    [[NSUserDefaults standardUserDefaults] setObject: auth.accessToken forKey:@"LIaccessToken"];
                }
                [self doRefreshStream];
            }];
        }
    } else {
        NSLog(@"not logged in");
        [self authForCBLSync:^{
            [self doRefreshStream];
        }];
    }
}

- (NSString*) docIDforUpdate:(NSMutableDictionary *)props {
    return [@[@"u",// for dedupe
             _cblSync.userID,
             props[@"updateKey"],
             [(NSNumber*)props[@"timestamp"] stringValue],
             props[@"updateContent"][@"person"][@"id"]]
        componentsJoinedByString:@":"];
}

-(void) saveStreamData: (NSDictionary*) streamData {
    NSArray *values = streamData[@"values"];
    NSError *e;
    for (NSDictionary *update in values) {
        NSMutableDictionary *props = [update mutableCopy];
        NSLog(@"my update %@", _cblSync.userID);
        props[@"userID"] = _cblSync.userID;
        CBLDocument* doc = [_database documentWithID:[self docIDforUpdate:props]];
        if (![doc currentRevisionID]) {
            [doc update:^BOOL(CBLUnsavedRevision * rev) {
                // todo only update if properties have changed
                [rev setUserProperties:props];
                return YES;
            } error:&e];
            NSLog(@"new rev %@ %@", [doc documentID],[doc currentRevisionID]);
        } else {
            NSLog(@"existing rev %@ %@", [doc documentID],[doc currentRevisionID]);
        }
    }
}


@end
