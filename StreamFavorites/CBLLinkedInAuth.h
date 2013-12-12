//
//  CBLLinkedInAuth.h
//  CBLIUpdateBrowser
//
//  Created by Chris Anderson on 12/5/13.
//  Copyright (c) 2013 Chris Anderson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CouchbaseLite/CouchbaseLite.h>
#import "CBLSyncManager.h"
#import "LIALinkedInApplication.h"
#import "LIALinkedInHttpClient.h"

@interface CBLLinkedInAuth : NSObject<CBLSyncAuthenticator>

- (instancetype) initWithClientID:(NSString *)cID clientSecret:(NSString * )secret redirectURL:(NSString*)url;


- (instancetype) initWithClientID:(NSString *)cID clientSecret:(NSString * )secret redirectURL:(NSString*)url grantedAccess: (NSArray *)access;

@property (readonly) LIALinkedInHttpClient *client;
@property (readonly) NSString *accessToken;

@end
