// daemophone - an MPD client for iPad
// Copyright (C) 2010 Aaron Griffith
//
// This file is licensed under the GNU GPL v2. See
// the file "main.m" for details.

#import <UIKit/UIKit.h>

#import "DPTableViewController.h"

@interface DPPlaylistViewController : DPTableViewController <UITableViewDelegate, UITableViewDataSource, UIPopoverControllerDelegate, UISplitViewControllerDelegate>
{
	UIToolbar* toolbar;
	UIBarButtonItem* popoverButton;
	UIPopoverController* popover;
	
	UILabel* currentTitle;
	UILabel* currentAlbum;
	UILabel* currentArtist;
	UILabel* nextSongLabel;
	UILabel* nextSong;
	int currentPlaylistPosition;
	
	UIButton* playButton;
	UIButton* stopButton;
	UIButton* nextButton;
	UIButton* prevButton;
	
	NSTimer* positionTimer;
	NSDate* songPositionTimestamp;
	BOOL isPaused, isPlaying;
	UILabel* elapsedTimeLabel;
	UILabel* remainingTimeLabel;
	UIProgressView* seekBar;
	unsigned int elapsedTime;
	unsigned int totalTime;
	
	NSArray* playlist;
	UITableView* playlistTableView;
}

@property (nonatomic, retain) IBOutlet UIToolbar* toolbar;
@property (nonatomic, retain) IBOutlet UIBarButtonItem* popoverButton;

@property (nonatomic, retain) IBOutlet UILabel* currentTitle;
@property (nonatomic, retain) IBOutlet UILabel* currentAlbum;
@property (nonatomic, retain) IBOutlet UILabel* currentArtist;
@property (nonatomic, retain) IBOutlet UILabel* nextSongLabel;
@property (nonatomic, retain) IBOutlet UILabel* nextSong;

@property (nonatomic, retain) IBOutlet UIButton* playButton;
@property (nonatomic, retain) IBOutlet UIButton* stopButton;
@property (nonatomic, retain) IBOutlet UIButton* nextButton;
@property (nonatomic, retain) IBOutlet UIButton* prevButton;

@property (nonatomic, retain) IBOutlet UILabel* elapsedTimeLabel;
@property (nonatomic, retain) IBOutlet UILabel* remainingTimeLabel;
@property (nonatomic, retain) IBOutlet UIProgressView* seekBar;

@property (nonatomic, retain) IBOutlet UITableView* playlistTableView;

- (IBAction) showSettings: (id) button;
- (IBAction) togglePopover: (id) button;

- (IBAction) playerControlAction: (id) button;

- (void) updateCurrentSong;
- (void) updateCurrentSongPosition;
- (void) updateControls;
- (void) updatePlaylist;

@end
