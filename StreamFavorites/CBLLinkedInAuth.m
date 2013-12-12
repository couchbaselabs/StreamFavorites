//
//  CBLLinkedInAuth.m
//  CBLIUpdateBrowser
//
//  Created by Chris Anderson on 12/5/13.
//  Copyright (c) 2013 Chris Anderson. All rights reserved.
//

#import "CBLLinkedInAuth.h"


NSString* CBLLinkedInUUIDString() {
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    CFStringRef string = CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);
    return (NSString *)CFBridgingRelease(string);
}

@implementation CBLLinkedInAuth {
    NSString *clientID;
    NSString *clientSecret;
    NSString *clientNonce;
    NSString *redirectURL;
    NSArray *grantedAccess;
    BOOL gettingCredentials;
}

@synthesize syncManager=_syncManager;

- (instancetype) initWithClientID:(NSString *)cID clientSecret:(NSString * )secret redirectURL:(NSString*)url {
    NSArray *access = @[@"r_fullprofile", @"r_network", @"w_messages", @"r_emailaddress", @"rw_nus"];
    return [self initWithClientID:cID clientSecret:secret redirectURL:url grantedAccess:access];
}

- (instancetype) initWithClientID:(NSString *)cID clientSecret:(NSString * )secret redirectURL:(NSString*)url grantedAccess: (NSArray *)access{
    self = [super init];
    if (self) {
        clientID = cID;
        clientSecret = secret;
        redirectURL = url;
        grantedAccess = access;
        clientNonce = CBLLinkedInUUIDString();
        [self createClient];
    }
    return self;
}

- (void) getCredentials:(void (^)(NSString * userID, NSDictionary * userData))block {
    NSLog(@"getCredentials start");
    if (![[UIApplication sharedApplication] keyWindow].rootViewController){
        NSLog(@"too early to getCredentials");
        return;
    }
    NSString* storedAccessToken = [[NSUserDefaults standardUserDefaults] objectForKey: @"LIaccessToken"];
    if (storedAccessToken) {
        NSLog(@"stored access token %@",storedAccessToken);
        _accessToken = storedAccessToken;
        [self sendAccessTokenToAuthenticationAgent: _accessToken complete:^(NSString *userID, NSDictionary *userData) {
            gettingCredentials = NO;
            block(userID, userData);
        }];
    } else {
        if (gettingCredentials) return;
        NSLog(@"getCredentials");
        gettingCredentials = YES;
        [_client getAuthorizationCode:^(NSString *code) {
            [_client getAccessToken:code success:^(NSDictionary *accessTokenData) {
                _accessToken = [accessTokenData objectForKey:@"access_token"];
                [self sendAccessTokenToAuthenticationAgent: _accessToken complete:^(NSString *userID, NSDictionary *userData) {
                    gettingCredentials = NO;
                    [[NSUserDefaults standardUserDefaults] setObject: _accessToken forKey:@"LIaccessToken"];
                    block(userID, userData);
                }];
            } failure:^(NSError *error) {
                gettingCredentials = NO;
                NSLog(@"Quering accessToken failed %@", error);
            }];
        } cancel:^{
            gettingCredentials = NO;
            NSLog(@"Authorization was cancelled by user");
        } failure:^(NSError *error) {
            gettingCredentials = NO;
            NSLog(@"Authorization failed %@", error);
        }];
    }
}

- (void) createClient {
    LIALinkedInApplication *application = [LIALinkedInApplication applicationWithRedirectURL:redirectURL clientId:clientID clientSecret:clientSecret state:clientNonce grantedAccess:grantedAccess];
    _client = [LIALinkedInHttpClient clientForApplication:application presentingViewController:nil];
}

- (void)sendAccessTokenToAuthenticationAgent: (NSString *)accessToken complete:(void (^)(NSString * userID, NSDictionary * userData))complete {
    LIALinkedInHttpClient *authAgentClient = [[LIALinkedInHttpClient alloc] initWithBaseURL:[self.syncManager.remoteURL baseURL]];
    [authAgentClient getPath:[@"/_access_token/" stringByAppendingString:accessToken] parameters:nil  success:^(AFHTTPRequestOperation *operation, NSDictionary *userData) {
        NSLog(@"Got userData %@ with accessToken %@", userData, accessToken);
        complete(userData[@"userID"], userData);
    }     failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Setting new accessToken failed %@", error);
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"LIaccessToken"];
        [self.syncManager restartSync];
    }];
}


- (void)registerCredentialsWithReplications:(NSArray *)repls {
    // no-op as sending the Access Token to the server is all it takes to
    // set the cookie
}

@end

