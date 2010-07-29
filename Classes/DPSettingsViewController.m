// daemophone - an MPD client for iPad
// Copyright (C) 2010 Aaron Griffith
//
// This file is licensed under the GNU GPL v2. See
// the file "main.m" for details.

#import "DPSettingsViewController.h"


@implementation DPSettingsViewController

@synthesize settingsTableView;

- (id) initWithNibName: (NSString*) nibNameOrNil bundle: (NSBundle*) nibBundleOrNil
{
    if ((self = [super initWithNibName: nibNameOrNil bundle: nibBundleOrNil]))
	{
		self.modalPresentationStyle = UIModalPresentationFormSheet;
		self.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    }
    return self;
}

- (void) viewDidLoad
{
    [super viewDidLoad];
	[mpclient setSettingsViewController: self];
}

- (void) viewDidUnload
{
    [super viewDidUnload];
	[mpclient setSettingsViewController: nil];
    
	self.settingsTableView = nil;
}

- (BOOL) shouldAutorotateToInterfaceOrientation: (UIInterfaceOrientation) interfaceOrientation
{
    // Overriden to allow any orientation.
    return YES;
}

- (void) didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void) dealloc
{
    [super dealloc];
}

#pragma mark update after new server info

- (void) updateOptions
{
	// just reload the table
	[settingsTableView reloadData];
}

#pragma mark Table View Data Source

- (NSInteger) numberOfSectionsInTableView: (UITableView*) tableView;
{
	return ESS_COUNT;
}

- (NSInteger) tableView: (UITableView*) tableView numberOfRowsInSection: (NSInteger) section
{
	switch (section)
	{
		case ESS_PLAYMODES:
			return EPM_COUNT;
	};
	return 0;
}

- (NSString*) tableView: (UITableView*) tableView titleForHeaderInSection: (NSInteger) section
{
	switch (section)
	{
		case ESS_PLAYMODES:
			return @"Play Modes";
	};
	return nil;
}

- (UITableViewCell*) tableView: (UITableView*) tableView cellForRowAtIndexPath: (NSIndexPath*) indexPath;
{	
	if ([indexPath section] == ESS_PLAYMODES)
	{
		UITableViewCell* cell = [self cellForTable: tableView withText: @"settings"];
		UISwitch* toggle = [[UISwitch alloc] initWithFrame: CGRectZero];
		[cell setAccessoryView: toggle];
		[toggle release];
		
		switch ([indexPath row])
		{
			case EPM_REPEAT:
				[cell.textLabel setText: @"Repeat"];
				[toggle setOn: [mpclient repeat]];
				break;
			case EPM_SINGLE:
				[cell.textLabel setText: @"Single"];
				[toggle setOn: [mpclient single]];
				break;
			case EPM_RANDOM:
				[cell.textLabel setText: @"Random"];
				[toggle setOn: [mpclient random]];
				break;
			case EPM_CONSUME:
				[cell.textLabel setText: @"Consume"];
				[toggle setOn: [mpclient consume]];
				break;
		}
		
		return cell;
	}
	
	return nil;
}

#pragma mark Table View Delegate

- (NSIndexPath*) tableView: (UITableView*) tableView willSelectRowAtIndexPath: (NSIndexPath*) indexPath
{
	// don't be selecting any settings, now
	return nil;
}

- (void) tableView: (UITableView*) tableView didSelectRowAtIndexPath: (NSIndexPath*) indexPath
{
	// just in case, and as a future template if we need selecting
	[tableView deselectRowAtIndexPath: indexPath animated: YES];
}

#pragma mark IB actions

- (IBAction) dismissSettings: (id) button
{
	[self.parentViewController dismissModalViewControllerAnimated: YES];
}


@end
