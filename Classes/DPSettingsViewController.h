// daemophone - an MPD client for iPad
// Copyright (C) 2010 Aaron Griffith
//
// This file is licensed under the GNU GPL v2. See
// the file "main.m" for details.

#import <UIKit/UIKit.h>

#import "DPTableViewController.h"

enum ESettingsSections
{
	ESS_PLAYMODES,
	ESS_COUNT
};

enum EPlayModes
{
	EPM_REPEAT,
	EPM_RANDOM,
	EPM_SINGLE,
	EPM_CONSUME,
	EPM_CROSSFADE,
	EPM_COUNT
};

@interface DPSettingsViewController : DPTableViewController <UITableViewDelegate, UITableViewDataSource>
{
	UITableView* settingsTableView;
}

@property (nonatomic, retain) IBOutlet UITableView* settingsTableView;

- (void) updateOptions;
- (IBAction) dismissSettings: (id) button;

@end
