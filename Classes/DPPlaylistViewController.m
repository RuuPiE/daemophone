// daemophone - an MPD client for iPad
// Copyright (C) 2010 Aaron Griffith
//
// This file is licensed under the GNU GPL v2. See
// the file "main.m" for details.

#import "DPPlaylistViewController.h"

#import "DPSettingsViewController.h"


@interface DPPlaylistViewController ()
@property (nonatomic, retain) UIPopoverController* popover;
- (void) songPositionTick: (id) unused;
@end


@implementation DPPlaylistViewController

@synthesize popover, toolbar, popoverButton;
@synthesize currentTitle, currentAlbum, currentArtist, nextSongLabel, nextSong;
@synthesize playButton, stopButton, nextButton, prevButton;
@synthesize elapsedTimeLabel, remainingTimeLabel, seekBar;
@synthesize playlistTableView;

#pragma mark viewcontroller stuff

/*
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id) initWithNibName: (NSString*) nibNameOrNil bundle: (NSBundle*) nibBundleOrNil
{
    if ((self = [super initWithNibName: nibNameOrNil bundle: nibBundleOrNil]))
	{
        // Custom initialization
    }
    return self;
}
*/

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void) viewDidLoad
{
    [super viewDidLoad];
	[mpclient setPlaylistViewController: self];
	positionTimer = [NSTimer scheduledTimerWithTimeInterval: 1.0 target: self selector: @selector(songPositionTick:) userInfo: nil repeats: YES];
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


- (void) viewDidUnload
{
    [super viewDidUnload];
	
	[positionTimer invalidate];
	//[positionTimer release];
	
	[mpclient setPlaylistViewController: nil];
	
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
	self.popover = nil;
	self.popoverButton = nil;
	self.toolbar = nil;
	
	self.currentTitle = nil;
	self.currentAlbum = nil;
	self.currentArtist = nil;
	self.nextSongLabel = nil;
	self.nextSong = nil;
	
	self.playButton = nil;
	self.stopButton = nil;
	self.nextButton = nil;
	self.prevButton = nil;
	
	self.elapsedTimeLabel = nil;
	self.remainingTimeLabel = nil;
	self.seekBar = nil;
	
	if (playlist)
		[playlist release];
	self.playlistTableView = nil;
}


- (void) dealloc
{
    [super dealloc];
}

#pragma mark DPClient callbacks and UI update functions

- (void) updateCurrentSong
{
	if (![mpclient isConnected])
	{
		// not connected
		[currentTitle setText: @"Not Connected"];
		[currentAlbum setText: @""];
		[currentArtist setText: @""];
		[nextSongLabel setText: @""];
		[nextSong setText: @""];
		return;
	}
	
	NSDictionary* info = [mpclient currentSongInfo];
	if (!info || !([mpclient isPlaying] || [mpclient isPaused]))
	{
		// no playing song
		[currentTitle setText: @"Not Playing"];
		[currentAlbum setText: @""];
		[currentArtist setText: @""];
		[nextSongLabel setText: @""];
		[nextSong setText: @""];
	} else {
		[currentTitle setText: [info objectForKey: @"title"]];
		[currentAlbum setText: [info objectForKey: @"album"]];
		[currentArtist setText: [info objectForKey: @"artist"]];
	}
	
	info = [mpclient nextSongInfo];
	if (!info || !([mpclient isPlaying] || [mpclient isPaused]))
	{
		[nextSongLabel setText: @""];
		[nextSong setText: @""];
	} else {
		[nextSongLabel setText: @"Next Up:"];
		[nextSong setText: [info objectForKey: @"title"]];
	}
	
	currentPlaylistPosition = -1;
	if ([mpclient isPlaying] || [mpclient isPaused])
		currentPlaylistPosition = [mpclient currentSongPlaylistPosition];
	[playlistTableView reloadData];
}

- (void) updateSongPositionUI
{
	NSString* tmp;
	
	unsigned int realElapsedTime = elapsedTime;
	if (!isPaused)
		realElapsedTime -= [songPositionTimestamp timeIntervalSinceNow];
	
	tmp = [[NSString alloc] initWithFormat: @"%i:%02i", realElapsedTime / 60, realElapsedTime % 60];
	[elapsedTimeLabel setText: tmp];
	[tmp release];
	
	unsigned int remainingTime = totalTime - realElapsedTime;
	
	tmp = [[NSString alloc] initWithFormat: @"-%i:%02i", remainingTime / 60, remainingTime % 60];
	[remainingTimeLabel setText: tmp];
	[tmp release];
	
	[seekBar setProgress: (float)realElapsedTime / totalTime];
}

- (void) songPositionTick: (id) unused
{
	if (totalTime == 0 || songPositionTimestamp == nil)
		return;
	[self updateSongPositionUI];
}

- (void) updateCurrentSongPosition
{
	if (songPositionTimestamp != nil)
		[songPositionTimestamp release];
	songPositionTimestamp = [[NSDate alloc] init];
	elapsedTime = [mpclient currentSongPosition];
	totalTime = [mpclient currentSongLength];
	[self updateSongPositionUI];
}

- (void) updateControls
{
	BOOL controlsEnabled = [mpclient isConnected];
	[playButton setEnabled: controlsEnabled];
	[stopButton setEnabled: controlsEnabled];
	[nextButton setEnabled: controlsEnabled];
	[prevButton setEnabled: controlsEnabled];
	
	UIImage* playButtonImage = nil;
	if ([mpclient isPlaying])
	{
		playButtonImage = [[UIImage alloc] initWithContentsOfFile: [[NSBundle mainBundle] pathForResource: @"pause" ofType: @"png"]];
	} else {
		playButtonImage = [[UIImage alloc] initWithContentsOfFile: [[NSBundle mainBundle] pathForResource: @"play" ofType: @"png"]];
	}
	
	[playButton setImage: playButtonImage forState: UIControlStateNormal];
	[playButtonImage release];
	
	BOOL showSeekBar = [mpclient isPlaying] || [mpclient isPaused];
	[elapsedTimeLabel setHidden: !showSeekBar];
	[remainingTimeLabel setHidden: !showSeekBar];
	[seekBar setHidden: !showSeekBar];
	
	isPaused = [mpclient isPaused];
	isPlaying = [mpclient isPlaying];
}

- (void) updatePlaylist
{
	if (playlist)
		[playlist release];
	playlist = [mpclient playlist];
	[playlist retain];
	[playlistTableView reloadData];
}

#pragma mark Table View Data Source

- (NSInteger) numberOfSectionsInTableView: (UITableView*) tableView;
{
	return 1;
}

- (NSInteger) tableView: (UITableView*) tableView numberOfRowsInSection: (NSInteger) section
{
	if (playlist == nil)
		return 0;
	return [playlist count];
}

- (NSString*) tableView: (UITableView*) tableView titleForHeaderInSection: (NSInteger) section
{
	return nil;
}

- (UITableViewCell*) tableView: (UITableView*) tableView cellForRowAtIndexPath: (NSIndexPath*) indexPath;
{
	if (playlist == nil)
		return nil;
	NSDictionary* data = [playlist objectAtIndex: [indexPath row]];
	//NSLog(@"%@", data);
	return [self playlistCellForTable: tableView withData: data isActive: [indexPath row] == currentPlaylistPosition];
}

#pragma mark Table View Delegate

- (NSIndexPath*) tableView: (UITableView*) tableView willSelectRowAtIndexPath: (NSIndexPath*) indexPath
{
	return indexPath;
}

- (void) tableView: (UITableView*) tableView didSelectRowAtIndexPath: (NSIndexPath*) indexPath
{
	// playlist logic
	
	[mpclient playPlaylistPosition: [indexPath row]];
	
	[tableView deselectRowAtIndexPath: indexPath animated: YES];
}

#pragma mark split view delegate stuff

- (void) splitViewController: (UISplitViewController*) svc willHideViewController: (UIViewController*) aViewController withBarButtonItem: (UIBarButtonItem*) barButtonItem forPopoverController: (UIPopoverController*) pc
{
	self.popover = pc;
	
	NSArray* passthroughs = [[NSArray alloc] initWithObjects: self.view, nil];
	[self.popover setPassthroughViews: passthroughs];
	[passthroughs release];
	
	NSMutableArray* items = [[toolbar items] mutableCopy];
	[items addObject: popoverButton];
	[toolbar setItems: items animated: YES];
	[items release];
	
	// we set the size manually so we're sure we can hit the toggle button again
	// 700px /just/ fits inside the playlist table view
	CGSize size;
	size.width = 320;
	size.height = 700;
	[popover setPopoverContentSize: size];
}

- (void) splitViewController: (UISplitViewController*) svc willShowViewController: (UIViewController*) aViewController invalidatingBarButtonItem: (UIBarButtonItem*) barButtonItem
{
	self.popover = nil;
	
	NSMutableArray* items = [[toolbar items] mutableCopy];
	[items removeLastObject];
	[toolbar setItems: items animated: YES];
	[items release];
}

#pragma mark IB actions

- (IBAction) showSettings: (id) button
{
	DPSettingsViewController* settings = [[DPSettingsViewController alloc] initWithNibName: @"DPSettingsViewController" bundle: nil];
	[self.splitViewController presentModalViewController: settings animated: YES];
	[settings release];
}

- (IBAction) togglePopover: (id) button
{
	if (popover == nil)
		return;
	if (popover.popoverVisible == YES)
	{
		[popover dismissPopoverAnimated: YES];
	}
	[popover presentPopoverFromBarButtonItem: popoverButton permittedArrowDirections: UIPopoverArrowDirectionDown animated: YES];
}

- (IBAction) playerControlAction: (id) button
{
	if (![mpclient isConnected])
		return;
	if (button == playButton)
	{
		if (isPlaying)
		{
			[mpclient pause];
		}
		else
		{
			[mpclient play];
		}
	} else if (button == stopButton) {
		[mpclient stop];
	} else if (button == nextButton) {
		[mpclient next];
	} else if (button == prevButton) {
		[mpclient previous];
	}
}


@end
