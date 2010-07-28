// daemophone - an MPD client for iPad
// Copyright (C) 2010 Aaron Griffith
//
// This file is licensed under the GNU GPL v2. See
// the file "main.m" for details.

#import <UIKit/UIKit.h>

#import "DPTableViewController.h"

@interface DPSettingsViewController : DPTableViewController <UITableViewDelegate, UITableViewDataSource>
{
	UITableView* settingsTableView;
}

@property (nonatomic, retain) IBOutlet UITableView* settingsTableView;

- (IBAction) dismissSettings: (id) button;

@end
