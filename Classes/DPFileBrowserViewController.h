// daemophone - an MPD client for iPad
// Copyright (C) 2010 Aaron Griffith
//
// This file is licensed under the GNU GPL v2. See
// the file "main.m" for details.

#import <UIKit/UIKit.h>

#import "DPTableViewController.h"

@interface DPFileBrowserViewController : DPTableViewController
{
	UITableView* browseTableView;
	NSArray* browseData;
	NSString* path;
}

@property (nonatomic, retain) IBOutlet UITableView* browseTableView;
@property (nonatomic, copy) NSString* path;

- (void) updateServerInfo;

@end
