//
//  CBFirstViewController.m
//  StreamFavorites
//
//  Created by Chris Anderson on 12/9/13.
//  Copyright (c) 2013 Chris Anderson. All rights reserved.
//

#import "CBFavoriteUpdatesViewController.h"


@interface CBFavoriteUpdatesViewController ()
@end

@implementation CBFavoriteUpdatesViewController
@synthesize app, dataSource;

- (void) setupDataSource {
    NSAssert(dataSource, @"_dataSource not connected");
    //    swap out the query based on which pane is selected , see the other view controler
    dataSource.query = [CBLIUpdate queryRecentFavoritesInDatabase: app.database].asLiveQuery;
    
}


- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    app = [[UIApplication sharedApplication] delegate];
    [self setupDataSource];
    
    
}

- (void) viewWillAppear:(BOOL)animated {
}

- (void)viewDidAppear:(BOOL)animated {
    [app refreshStream];
}



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(BOOL) prefersStatusBarHidden
{
    return YES;
}


#pragma mark - Table View


// override the CBLUITableView default cell to use the Subtitle style
- (UITableViewCell *)couchTableSource:(CBLUITableSource*)source
                cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [source.tableView dequeueReusableCellWithIdentifier: @"CBLIUITableDelegate"];
    if (!cell)
        cell = [[UITableViewCell alloc] initWithStyle: UITableViewCellStyleSubtitle
                                      reuseIdentifier: @"CBLIUITableDelegate"];
    
    CBLQueryRow* row = [dataSource rowAtIndex: indexPath.row];
    CBLIUpdate* update = [CBLIUpdate modelForDocument: row.document];
    NSLog(@"fav %@ %@",row.document.properties[@"favorite"], update.favorite ? @"y":@"n");
    if (update.favorite) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    cell.textLabel.text = update.headline;
    cell.detailTextLabel.text = update.url;
    return cell;
}

// Delegate method called when the live-query results change.
- (void)couchTableSource:(CBLUITableSource*)source
         updateFromQuery:(CBLLiveQuery*)query
            previousRows:(NSArray *)previousRows
{
//    //    NSLog(@"couchTableSource previousRows %@",previousRows);
    
    [[self tableView] reloadData];
    
    //    if (!_initialLoadComplete) {
    //        // On initial table load on launch, decide which row/list to select:
    //        [self selectList: self.initialList];
    //        _initialLoadComplete = YES;
    //    }
}


#pragma mark - Table View


//todo call this from the table view
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    CBLQueryRow *row = [self.dataSource rowAtIndex:indexPath.row];
    CBLIUpdate* update = [CBLIUpdate modelForDocument: row.document];
    NSLog(@"didSelectRowAtIndexPath update %@",update.description);
    update.favorite=!update.favorite;
    NSError *e;
    [update save:&e];
}


@end
