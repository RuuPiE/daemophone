// daemophone - an MPD client for iPad
// Copyright (C) 2010, 2011 Aaron Griffith
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

// helper function to fetch data from the client, but not reload anything
- (void) fetchData
{
	/* reload data in the table */
	if (browseData)
		[browseData release];
	
	if (path == nil)
		self.path = @"/";
	
	// nil means either not connected, or error, and errors are usually fatal
	// so it's safe to assume browseData == nil => not connected
	// (no content is represented by an empty array)
	browseData = [mpclient getFiles: self.path];
	NSLog(@"using path: %@", self.path);
}

// additional setup after loading the view, typically from a nib.
- (void) viewDidLoad
{
	// we set the size manually so we're sure we can hit the toggle button again
	// 700px /just/ fits inside the playlist table view
	self.contentSizeForViewInPopover = CGSizeMake(320, 630);
	
	// only set the mpclient callback if we're the root fbrowser
	if ([self.navigationController.viewControllers objectAtIndex: 0] == self)
	{
		// set up the mpclient callback, which will then load our data
		mpclient.fileBrowserViewController = self;
		
		// also, set up our toolbar since we're root
		NSArray* toolbar_opts = [[NSArray alloc] initWithObjects: @"By File", @"By Artist", nil];
		UISegmentedControl* segment = [[UISegmentedControl alloc] initWithItems: toolbar_opts];
		[toolbar_opts release];
		
		[segment setSegmentedControlStyle: UISegmentedControlStyleBar];
		[segment setSelectedSegmentIndex: 0];
		
		UIBarButtonItem* barbutton = [[UIBarButtonItem alloc] initWithCustomView: segment];
		[segment release];
		
		UIBarButtonItem* flexyspace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemFlexibleSpace target: nil action: nil];
		
		NSArray* barArray = [[NSArray alloc] initWithObjects: flexyspace, barbutton, flexyspace, nil];
		[barbutton release];
		[flexyspace release];
		
		[self setToolbarItems: barArray animated: YES];
		[barArray release];
	} else {
		/* we must fetch the data manually this one time */
		[self fetchData];
		[browseTableView reloadData];
	}
	
    [super viewDidLoad];
}

- (void) viewDidUnload
{
	if (mpclient.fileBrowserViewController == self)
		mpclient.fileBrowserViewController = nil;
	
	self.browseTableView = nil;
	self.path = nil;
	
	if (browseData)
	{
		[browseData release];
		browseData = nil;
	}
	
    [super viewDidUnload];
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

#pragma mark Client Callbacks

- (void) updateServerInfo
{
	[self fetchData];
	
	/* reload the data all pretty-like */
	NSIndexSet* indexSet = [[NSIndexSet alloc] initWithIndex: 0];
	[browseTableView reloadSections: indexSet withRowAnimation: UITableViewRowAnimationFade];
	[indexSet release];
	
	/* reset the navigation view stack to the toplevel, we've just changed connection states! */
	NSArray* controllers = [[NSArray alloc] initWithObjects: self, nil];
	[self.navigationController setViewControllers: controllers animated: YES];
	[controllers release];
}

#pragma mark Table View Data Source

- (NSInteger) numberOfSectionsInTableView: (UITableView*) tableView;
{
	return 1;
}

- (NSInteger) tableView: (UITableView*) tableView numberOfRowsInSection: (NSInteger) section
{
	if (browseData)
	{
		// plus 1, for "add all" option
		return [browseData count] + 1;
	}
	
	/* we're not connected -- show message */
	return 1;
}

- (NSString*) tableView: (UITableView*) tableView titleForHeaderInSection: (NSInteger) section
{
	return nil;
}

- (UITableViewCell*) tableView: (UITableView*) tableView cellForRowAtIndexPath: (NSIndexPath*) indexPath;
{
	if (browseData == nil)
	{
		// FIXME nicer, greyer message cell
		return [self cellForTable: tableView withText: @"not connected"];
	}
	
	if ([indexPath row] == 0)
	{
		/* this is our "add all" option */
		return [self cellForTable: tableView withText: @"Add All" andImageNamed: @"add"];
	}
	
	NSDictionary* data = [browseData objectAtIndex: [indexPath row] - 1];
	//NSLog(@"celldata %@", data);
	UITableViewCell* cell = [self cellForTable: tableView withText: [data objectForKey: @"lastpath"]];
	
	if ([data objectForKey: @"type"] == @"song")
	{
		cell.imageView.image = [UIImage imageNamed: @"song"];
	} else if ([data objectForKey: @"type"] == @"directory") {
		cell.imageView.image = [UIImage imageNamed: @"folder"];
		[cell setAccessoryType: UITableViewCellAccessoryDisclosureIndicator];
	} else if ([data objectForKey: @"type"] == @"playlist") {
		cell.imageView.image = [UIImage imageNamed: @"playlist"];
	}
	
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
	
	if ([indexPath row] == 0)
	{
		/* add all option */
		[mpclient addSong: self.path];
		return;
	}
	
	NSDictionary* data = [browseData objectAtIndex: [indexPath row] - 1];
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
