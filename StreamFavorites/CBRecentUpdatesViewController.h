//
//  CBFirstViewController.h
//  StreamFavorites
//
//  Created by Chris Anderson on 12/9/13.
//  Copyright (c) 2013 Chris Anderson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Couchbaselite/CBLUITableSource.h>
#import "CBAppDelegate.h"
#import "CBLIUpdate.h"

@interface CBRecentUpdatesViewController : UIViewController <CBLUITableDelegate>
@property (readwrite)     CBAppDelegate *app;

@property (strong, nonatomic) IBOutlet CBLUITableSource *dataSource;

@property (strong, nonatomic) IBOutlet UITableView *tableView;

@end
