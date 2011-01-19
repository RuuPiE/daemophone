// daemophone - an MPD client for iPad
// Copyright (C) 2010, 2011 Aaron Griffith
//
// This file is licensed under the GNU GPL v2. See
// the file "main.m" for details.

#import <UIKit/UIKit.h>

@interface DPTableViewController : UIViewController
{
	UITableViewCell* newCell;
}

@property (nonatomic, retain) IBOutlet UITableViewCell* newCell;

- (UITableViewCell*) cellForTable: (UITableView*) tableView withIdentifier: (NSString*) cellIdentifier;
- (UITableViewCell*) cellForTable: (UITableView*) tableView withText: (NSString*) text andImageNamed: (NSString*) imageName;
- (UITableViewCell*) cellForTable: (UITableView*) tableView withText: (NSString*) text;
- (UITableViewCell*) playlistCellForTable: (UITableView*) tableView withData: (NSDictionary*) data isActive: (BOOL) playing;

@end
