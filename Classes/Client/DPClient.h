// daemophone - an MPD client for iPad
// Copyright (C) 2010 Aaron Griffith
//
// This file is licensed under the GNU GPL v2. See
// the file "main.m" for details.

#import <Foundation/Foundation.h>

#include <mpd/client.h>

// this is in ms (milliseconds: 1000ms / 1s
#define MPD_TIMEOUT			(4.00 * 1000)
#define MPD_IDLE_INTERVALS	(0.05 * 1000)
#define MPD_IDLE_MAX		(5.00 * 1000)
// the following is in SECONDS, and compensates for integer-only idle interval support
#define MPD_IDLE_INTERVAL_ADD (((unsigned int)MPD_IDLE_INTERVALS % 1000) / 1000.0)

// a little shortcut
#define mpclient ([DPClient sharedClient])

@class DPPlaylistViewController;
@class DPSettingsViewController;

@interface DPClient : NSObject
{
	DPPlaylistViewController* playlistViewController;
	DPSettingsViewController* settingsViewController;
	
	NSDictionary* currentSongInfo;
	NSDictionary* nextSongInfo;
	int currentSongPlaylistPosition;
	
	unsigned int currentSongLength;
	unsigned int currentSongPosition;
	BOOL isPlaying;
	BOOL isPaused;
	
	BOOL repeat;
	BOOL random;
	BOOL single;
	BOOL consume;
	
	NSArray* playlist;
	
	struct mpd_connection* mpd;
	NSThread* idleThread;
	unsigned int needInterruptNumber;
}

@property (nonatomic, retain) DPPlaylistViewController* playlistViewController;
@property (nonatomic, retain) DPSettingsViewController* settingsViewController;

@property (nonatomic, readonly) NSDictionary* currentSongInfo;
@property (nonatomic, readonly) NSDictionary* nextSongInfo;
@property (nonatomic, readonly) int currentSongPlaylistPosition;

@property (nonatomic, readonly) unsigned int currentSongLength;
@property (nonatomic, readonly) unsigned int currentSongPosition;
@property (nonatomic, readonly) BOOL isPlaying;
@property (nonatomic, readonly) BOOL isPaused;

@property (nonatomic, readonly) BOOL repeat;
@property (nonatomic, readonly) BOOL random;
@property (nonatomic, readonly) BOOL single;
@property (nonatomic, readonly) BOOL consume;

@property (nonatomic, readonly) NSArray* playlist;

+ (DPClient*) sharedClient;

- (void) updateAll;

// port == 0 gets passed straight to libmpdclient, so it means "default port" (6600)
- (BOOL) connectToHost: (NSString*) host port: (unsigned int) port;
- (void) disconnect;
- (BOOL) isConnected;

- (void) next;
- (void) previous;
- (void) stop;
- (void) play;
- (void) pause;

- (void) playPlaylistPosition: (unsigned int) pos;

@end
