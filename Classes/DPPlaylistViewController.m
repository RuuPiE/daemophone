// daemophone - an MPD client for iPad
// Copyright (C) 2010 Aaron Griffith
//
// This file is licensed under the GNU GPL v2. See
// the file "main.m" for details.

#import "DPPlaylistViewController.h"

#import "DPSettingsViewController.h"
#import "UILabel+SetTextAnimated.h"

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
	
	// clear out the interface builder dummy text so it doesn't show up during animation
	[currentTitle setText: @""];
	[currentAlbum setText: @""];
	[currentArtist setText: @""];
	[nextSongLabel setText: @""];
	[nextSong setText: @""];
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
		[currentTitle setText: @"Not Connected" animated: YES];
		[currentAlbum setText: @"" animated: YES];
		[currentArtist setText: @"" animated: YES];
		[nextSongLabel setText: @"" animated: YES];
		[nextSong setText: @"" animated: YES];
		return;
	}
	
	NSDictionary* info = [mpclient currentSongInfo];
	if (!info || !([mpclient isPlaying] || [mpclient isPaused]))
	{
		// no playing song
		[currentTitle setText: @"Not Playing" animated: YES];
		[currentAlbum setText: @"" animated: YES];
		[currentArtist setText: @"" animated: YES];
		[nextSongLabel setText: @"" animated: YES];
		[nextSong setText: @"" animated: YES];
	} else {
		[currentTitle setText: [info objectForKey: @"title"] animated: YES];
		[currentAlbum setText: [info objectForKey: @"album"] animated: YES];
		[currentArtist setText: [info objectForKey: @"artist"] animated: YES];
	}
	
	info = [mpclient nextSongInfo];
	if (!info || !([mpclient isPlaying] || [mpclient isPaused]))
	{
		[nextSongLabel setText: @"" animated: YES];
		[nextSong setText: @"" animated: YES];
	} else {
		[nextSongLabel setText: @"Next Up:" animated: YES];
		[nextSong setText: [info objectForKey: @"title"] animated: YES];
	}
	
	int lastPlaylistPosition = currentPlaylistPosition;
	
	currentPlaylistPosition = -1;
	if ([mpclient isPlaying] || [mpclient isPaused])
		currentPlaylistPosition = [mpclient currentSongPlaylistPosition];

	// prevent creating two animations for one cell
	if (currentPlaylistPosition != lastPlaylistPosition)
	{
		NSMutableArray* indexPaths = [[NSMutableArray alloc] initWithCapacity: 2];
		
		if (lastPlaylistPosition != -1)
			[indexPaths addObject: [NSIndexPath indexPathForRow: lastPlaylistPosition inSection: 0]];
		if (currentPlaylistPosition != -1)
			[indexPaths addObject: [NSIndexPath indexPathForRow: currentPlaylistPosition inSection: 0]];
		
		[playlistTableView reloadRowsAtIndexPaths: indexPaths withRowAnimation: UITableViewRowAnimationFade];
		[indexPaths release];
	}
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
	
	NSRange range;
	range.location = 0;
	range.length = 1;
	NSIndexSet* indexSet = [[NSIndexSet alloc] initWithIndexesInRange: range];
	[playlistTableView reloadSections: indexSet withRowAnimation: UITableViewRowAnimationFade];
	[indexSet release];
	//[playlistTableView reloadData];
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
	
	// only change songs if we touched a *different* song
	if (currentPlaylistPosition != [indexPath row])
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
	// no animations -> no weird popover errors
	[toolbar setItems: items animated: NO];
	[items release];
	
	// we set the size manually so we're sure we can hit the toggle button again
	// 700px /just/ fits inside the playlist table view
	CGSize size;
	size.width = 320;
	size.height = 700;
	[popover setPopoverContentSize: size];
	
	// show the popover so that people know it's MOVED from where it is normally
	// we show it on the right instead of the usual left so that people can still
	// read and interact meaningfully with the playlist
	// showing it automatically helps people find it, and they can hide it if they want
	
	// we can't do this right away, or the popover present will fail when we open
	// the app in portrait mode (this view has no window, and the popover complains)
	// so, we use a timer, and reuse our togglePopover: selector
	
	// also, a delay is nice so it plays well with the orientation change
	
	[NSTimer scheduledTimerWithTimeInterval: 0.6 target: self selector: @selector(togglePopover:) userInfo: popoverButton repeats: NO];
}

- (void) splitViewController: (UISplitViewController*) svc willShowViewController: (UIViewController*) aViewController invalidatingBarButtonItem: (UIBarButtonItem*) barButtonItem
{
	if (popover.popoverVisible)
		[popover dismissPopoverAnimated: NO];
	self.popover = nil;
	
	NSMutableArray* items = [[toolbar items] mutableCopy];
	[items removeLastObject];
	// no animations -> no weird popover errors
	[toolbar setItems: items animated: NO];
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
	
	// a more subtle problem may be that our button is not actually /in/ the toolbar anymore
	if (![toolbar.items containsObject: popoverButton])
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
