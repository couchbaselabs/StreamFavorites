#import <UIKit/UIKit.h>
#import <Couchbaselite/CBLUITableSource.h>
#import "CBAppDelegate.h"
#import "CBLIUpdate.h"

@interface CBFavoriteUpdatesViewController : UIViewController <CBLUITableDelegate>
@property (readwrite)     CBAppDelegate *app;

@property (strong, nonatomic) IBOutlet CBLUITableSource *dataSource;

@property (strong, nonatomic) IBOutlet UITableView *tableView;

@end