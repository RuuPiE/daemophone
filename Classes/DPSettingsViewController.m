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
}

- (void) viewDidUnload
{
    [super viewDidUnload];
    
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

#pragma mark Table View Data Source

- (NSInteger) numberOfSectionsInTableView: (UITableView*) tableView;
{
	return 1;
}

- (NSInteger) tableView: (UITableView*) tableView numberOfRowsInSection: (NSInteger) section
{
	return 10;
}

- (NSString*) tableView: (UITableView*) tableView titleForHeaderInSection: (NSInteger) section
{
	return nil;
}

- (UITableViewCell*) tableView: (UITableView*) tableView cellForRowAtIndexPath: (NSIndexPath*) indexPath;
{
	UITableViewCell* cell = [self cellForTable: tableView withText: @"settings"];
	UISwitch* toggle = [[UISwitch alloc] initWithFrame: CGRectZero];
	[cell setAccessoryView: toggle];
	[toggle release];
	
	return cell;
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
