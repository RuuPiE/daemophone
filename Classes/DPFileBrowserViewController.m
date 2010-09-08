// daemophone - an MPD client for iPad
// Copyright (C) 2010 Aaron Griffith
//
// This file is licensed under the GNU GPL v2. See
// the file "main.m" for details.

#import "DPFileBrowserViewController.h"


@implementation DPFileBrowserViewController

@synthesize browseTableView;
@synthesize path;

 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
/*- (id) initWithNibName: (NSString*) nibNameOrNil bundle: (NSBundle*) nibBundleOrNil
{
    if ((self = [super initWithNibName: nibNameOrNil bundle: nibBundleOrNil]))
	{
		//
    }
    return self;
}*/

- (void) dealloc
{
    [super dealloc];
}

// additional setup after loading the view, typically from a nib.
- (void) viewDidLoad
{
	// we set the size manually so we're sure we can hit the toggle button again
	// 700px /just/ fits inside the playlist table view
	self.contentSizeForViewInPopover = CGSizeMake(320, 630);
	
    [super viewDidLoad];
}

- (void) viewDidUnload
{
	self.browseTableView = nil;
	self.path = nil;
	
	if (browseData)
	{
		[browseData release];
		browseData = nil;
	}
	
    [super viewDidUnload];
}

- (void) viewWillAppear: (BOOL) animated
{
	if (browseData)
		[browseData release];
	
	NSString* usepath = path;
	if (usepath == nil)
		usepath = @"/";
	
	browseData = [mpclient getFiles: usepath];
	NSLog(@"using path: %@", usepath);
	[browseTableView reloadData];
}

- (void) didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (BOOL) shouldAutorotateToInterfaceOrientation: (UIInterfaceOrientation) interfaceOrientation
{
    // Overriden to allow any orientation.
    return YES;
}

#pragma mark Table View Data Source

- (NSInteger) numberOfSectionsInTableView: (UITableView*) tableView;
{
	return 1;
}

- (NSInteger) tableView: (UITableView*) tableView numberOfRowsInSection: (NSInteger) section
{
	if (browseData)
		return [browseData count];
	return 0;
}

- (NSString*) tableView: (UITableView*) tableView titleForHeaderInSection: (NSInteger) section
{
	return nil;
}

- (UITableViewCell*) tableView: (UITableView*) tableView cellForRowAtIndexPath: (NSIndexPath*) indexPath;
{
	if (browseData == nil)
		return nil;
	
	NSDictionary* data = [browseData objectAtIndex: [indexPath row]];
	NSLog(@"celldata %@", data);
	UITableViewCell* cell = [self cellForTable: tableView withText: [data objectForKey: @"lastpath"]];
	if ([data objectForKey: @"type"] == @"directory")
		[cell setAccessoryType: UITableViewCellAccessoryDisclosureIndicator];
	return cell;
}

#pragma mark Table View Delegate

- (NSIndexPath*) tableView: (UITableView*) tableView willSelectRowAtIndexPath: (NSIndexPath*) indexPath
{
	// navigation logic
	return indexPath;
}

- (void) tableView: (UITableView*) tableView didSelectRowAtIndexPath: (NSIndexPath*) indexPath
{
	// navigation logic
	if (browseData == nil)
		return;
	
	[browseTableView deselectRowAtIndexPath: indexPath animated: YES];
	
	NSDictionary* data = [browseData objectAtIndex: [indexPath row]];
	NSString* type = [data objectForKey: @"type"];
	
	if (type == @"directory")
	{
		// navigate!
		
		DPFileBrowserViewController* newvc = [[DPFileBrowserViewController alloc] initWithNibName: @"DPFileBrowserViewController" bundle: nil];
		newvc.path = [data objectForKey: @"path"];
		newvc.navigationItem.title = [data objectForKey: @"lastpath"];
		[self.navigationController pushViewController: newvc animated: YES];
		[newvc release];
	} else if (type == @"song") {
		/* add! */
		
		[mpclient addSong: [data objectForKey: @"path"]];
	}
}

@end
