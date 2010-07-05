// daemophone - an MPD client for iPad
// Copyright (C) 2010 Aaron Griffith
//
// This file is licensed under the GNU GPL v2. See
// the file "main.m" for details.

#import "DPClient.h"

#import "DPPlaylistViewController.h"

@interface DPClient ()
- (void) idleThreadSelector: (id) unused;
// returns true if there was an error
- (BOOL) handleError: (NSString*) part;
- (NSDictionary*) convertSongInfo: (struct mpd_song*) song;

// wrap all time-relevant @synchronize calls in this to get
// fair access to mpd connection from idle thread
- (void) preLock;
- (void) postLock;
- (BOOL) needInterrupt;

// we want this ATOMIC where possible
@property (assign) unsigned int needInterruptNumber;
@end

@implementation DPClient

@synthesize needInterruptNumber;
@synthesize currentSongInfo, nextSongInfo;
@synthesize currentSongLength, currentSongPosition, isPlaying, isPaused;
@synthesize playlist, currentSongPlaylistPosition;

#pragma mark interrupt handling

- (void) preLock
{
	if ([NSThread currentThread] == idleThread)
		return;
	unsigned int needers = [self needInterruptNumber];
	needers++;
	[self setNeedInterruptNumber: needers];
}

- (void) postLock
{
	if ([NSThread currentThread] == idleThread)
		return;
	unsigned int needers = [self needInterruptNumber];
	assert(needers >= 1);
	needers--;
	[self setNeedInterruptNumber: needers];
}

- (BOOL) needInterrupt
{
	return [self needInterruptNumber] > 0;
}

#pragma mark update conveniences

- (void) updatePlayer
{	
	// player state
	if (mpd)
	{
		int next_song_id = -1, current_song_id = -1;
		@synchronized(self)
		{
			struct mpd_status* status = mpd_run_status(mpd);
			if ([self handleError: @"could not get status"])
				return;
			
			currentSongLength = mpd_status_get_total_time(status);
			currentSongPosition = mpd_status_get_elapsed_time(status);
			isPlaying = mpd_status_get_state(status) == MPD_STATE_PLAY;
			isPaused = mpd_status_get_state(status) == MPD_STATE_PAUSE;
			
			current_song_id = mpd_status_get_song_id(status);
			next_song_id = mpd_status_get_next_song_id(status);
			currentSongPlaylistPosition = mpd_status_get_song_pos(status);
			
			mpd_status_free(status);
		}
		
		// current / next songs
		if (nextSongInfo != nil)
			[nextSongInfo release];
		nextSongInfo = nil;
		if (currentSongInfo != nil)
			[currentSongInfo release];
		currentSongInfo = nil;
		if (current_song_id != -1)
		{
			struct mpd_song* song = mpd_run_get_queue_song_id(mpd, current_song_id);
			if ([self handleError: @"could not get current song"])
				return;
			currentSongInfo = [self convertSongInfo: song];
		}
		if (next_song_id != -1)
		{
			struct mpd_song* song = mpd_run_get_queue_song_id(mpd, next_song_id);
			if ([self handleError: @"could not get next song"])
				return;
			nextSongInfo = [self convertSongInfo: song];
		}
	}
	
	if (playlistViewController != nil)
	{
		[playlistViewController performSelectorOnMainThread: @selector(updateCurrentSong) withObject: nil waitUntilDone: NO];
		[playlistViewController performSelectorOnMainThread: @selector(updateCurrentSongPosition) withObject: nil waitUntilDone: NO];
		[playlistViewController performSelectorOnMainThread: @selector(updateControls) withObject: nil waitUntilDone: NO];
	}
}

- (void) updateQueue
{
	if (playlist)
		[playlist release];
	
	if (mpd)
	{
		NSMutableArray* mutablePlaylist = [[NSMutableArray alloc] init];
		
		@synchronized(self)
		{
			struct mpd_song* song;
			mpd_send_list_queue_meta(mpd);
			
			while (song = mpd_recv_song(mpd))
			{
				NSDictionary* songInfo = [self convertSongInfo: song];
				[mutablePlaylist addObject: songInfo];
				[songInfo release];
			}
			
			if ([self handleError: @"could not get playlist"])
			{
				[mutablePlaylist release];
				return;
			}
		}
		
		playlist = mutablePlaylist;
	} else {
		playlist = nil;
	}
	
	if (playlistViewController != nil)
	{
		[playlistViewController performSelectorOnMainThread: @selector(updatePlaylist) withObject: nil waitUntilDone: NO];
	}
}

- (void) updateAll
{
	// player can use info from the queue, so update queue before player
	[self updateQueue];
	[self updatePlayer];
}

#pragma mark getters / setters

- (DPPlaylistViewController*) playlistViewController
{
	return playlistViewController;
}

- (void) setPlaylistViewController: (DPPlaylistViewController*) pvc
{
	if (playlistViewController != nil)
		[playlistViewController release];
	playlistViewController = pvc;
	if (playlistViewController != nil)
		[playlistViewController retain];
	
	[playlistViewController updateCurrentSong];
	[playlistViewController updateCurrentSongPosition];
	[playlistViewController updateControls];
}

- (void) dealloc
{
	[self disconnect];
	
	self.playlistViewController = nil;
	
	if (currentSongInfo != nil)
		[currentSongInfo release];
	
	if (nextSongInfo != nil)
		[nextSongInfo release];
	
	if (playlist != nil)
		[playlist release];
	
	[super dealloc];
}

#pragma mark idle thread

- (void) idleThreadSelector: (id) unused
{
	// setup
	NSLog(@"mpd idle: thread started");
	[self updateAll];
	
	while (![[NSThread currentThread] isCancelled])
	{
		enum mpd_idle events = 0;
		
		@synchronized(self)
		{
			//NSLog(@"forcing new idle");
			NSDate* sentDate = [[NSDate alloc] init];
			mpd_send_idle(mpd);
			mpd_connection_set_timeout(mpd, MPD_IDLE_INTERVALS);
			while (![[NSThread currentThread] isCancelled])
			{
				BOOL last_of_round = NO;
				if (-[sentDate timeIntervalSinceNow] >= (MPD_IDLE_MAX/ 1000.0) || [self needInterrupt])
				{
					//NSLog(@"sending noidle");
					mpd_send_noidle(mpd);
					// block if we're on the last recv
					events = mpd_recv_idle(mpd, YES);
					last_of_round = YES;
				} else {
					events = mpd_recv_idle(mpd, NO);
#ifdef MPD_IDLE_INTERVAL_ADD
					[NSThread sleepForTimeInterval: MPD_IDLE_INTERVAL_ADD];
#endif
				}
				
				if (!mpd_response_finish(mpd))
					events = 0;
				
				enum mpd_error error = mpd_connection_get_error(mpd);
				if (error == MPD_ERROR_SUCCESS)
				{
					break;
				} else if (error == MPD_ERROR_TIMEOUT) {
					//NSLog(@"timeout");
					// let's force it... I know what I'm doing (I think)
					mpd_connection_clear_error_force(mpd);
					
					// if we're above our max, let's get out of here
					if (last_of_round)
						break;
					
					continue;
				} else {
					if ([self handleError: @"idle thread error:"])
						break;
				}
			}
			[sentDate release];
			mpd_connection_set_timeout(mpd, MPD_TIMEOUT);
		}
		
		if (events == 0)
			continue;
		
		NSLog(@"mpd idle: events: %i", events);
		
		if (events & MPD_IDLE_PLAYER)
			[self updatePlayer];
		if (events & MPD_IDLE_QUEUE)
		{
			// update queue *and* player -- player handles currently playing queue item
			[self updateQueue];
			[self updatePlayer];
		}
		
		while ([self needInterrupt])
			[NSThread sleepForTimeInterval: MPD_IDLE_INTERVALS / 1000.0];
	}
	
	// teardown (don't trust mpd, may be that mpd == NULL)
	NSLog(@"mpd idle: thread stopping");
}

#pragma mark connection managing

- (BOOL) connectToHost: (NSString*) host port: (unsigned int) port
{
	@synchronized(self)
	{
		if (mpd != NULL)
			[self disconnect];
		
		mpd = mpd_connection_new([host cStringUsingEncoding: NSUTF8StringEncoding], port, MPD_TIMEOUT);
		
		if (mpd_connection_get_error(mpd) != MPD_ERROR_SUCCESS)
		{
			NSLog(@"mpd error: could not connect: %s", mpd_connection_get_error_message(mpd));
			mpd_connection_free(mpd);
			mpd = NULL;
			return NO;
		}
		
		const unsigned int* version = mpd_connection_get_server_version(mpd);
		NSLog(@"mpd: connected to %@:%i, protocol version %i.%i.%i", host, port, version[0], version[1], version[2]);
	}
	
	idleThread = [[NSThread alloc] initWithTarget: self selector: @selector(idleThreadSelector:) object: nil];
	[idleThread start];
	
	return YES;
}

- (void) disconnect
{
	[self preLock];
	@synchronized(self)
	{
		if (mpd == NULL)
			return;
	}
	[self postLock];
	
	if ([NSThread currentThread] != idleThread)
	{
		[idleThread cancel];
		while (![idleThread isFinished]) [NSThread sleepForTimeInterval: 0.1];
	}
	
	@synchronized(self)
	{
		mpd_connection_free(mpd);
		[idleThread release];
		mpd = NULL;
		idleThread = nil;
		NSLog(@"mpd: disconnected");
	}
	
	[self updateAll];
}

- (BOOL) isConnected
{
	return (mpd != NULL);
}

- (BOOL) handleError: (NSString*) part
{
	@synchronized(self)
	{
		if (mpd_connection_get_error(mpd) != MPD_ERROR_SUCCESS)
		{
			NSLog(@"mpd error: %@: %s", part, mpd_connection_get_error_message(mpd));
			if (mpd_connection_clear_error(mpd) == NO)
				[self disconnect];
			return YES;
		}
	}
	return NO;
}

#pragma mark Song Info Stuff

- (NSDictionary*) convertSongInfo: (struct mpd_song*) song
{
	if (song == NULL)
		return nil;
	
	NSMutableDictionary* info = [[NSMutableDictionary alloc] init];
	
	NSString* tmp;
	const char* tmpc;
	
	tmpc = mpd_song_get_tag(song, MPD_TAG_ARTIST, 0);
	if (tmpc != NULL)
	{
		tmp = [[NSString alloc] initWithCString: tmpc];
		[info setObject: tmp forKey: @"artist"];
		[tmp release];
	}
	
	tmpc = mpd_song_get_tag(song, MPD_TAG_ALBUM, 0);
	if (tmpc != NULL)
	{
		tmp = [[NSString alloc] initWithCString: tmpc];
		[info setObject: tmp forKey: @"album"];
		[tmp release];
	}
	
	tmpc = mpd_song_get_tag(song, MPD_TAG_TITLE, 0);
	if (tmpc != NULL)
	{
		tmp = [[NSString alloc] initWithCString: tmpc];
		[info setObject: tmp forKey: @"title"];
		[tmp release];
	}
	
	tmpc = mpd_song_get_uri(song);
	if (tmpc != NULL)
	{
		tmp = [[NSString alloc] initWithCString: tmpc];
		[info setObject: tmp forKey: @"uri"];
		[tmp release];
	}
	
	mpd_song_free(song);
	return info;
}

#pragma mark player controls

- (void) next
{
	[self preLock];
	@synchronized(self)
	{
		mpd_run_next(mpd);
		[self handleError: @"could not modify player state"];
	}
	[self postLock];
}

- (void) previous
{
	[self preLock];
	@synchronized(self)
	{
		mpd_run_previous(mpd);
		[self handleError: @"could not modify player state"];
	}
	[self postLock];
}

- (void) stop
{
	[self preLock];
	@synchronized(self)
	{
		mpd_run_stop(mpd);
		[self handleError: @"could not modify player state"];
	}
	[self postLock];
}

- (void) play
{
	[self preLock];
	@synchronized(self)
	{
		mpd_run_play(mpd);
		[self handleError: @"could not modify player state"];
	}
	[self postLock];
}

- (void) pause
{
	[self preLock];
	@synchronized(self)
	{
		mpd_run_pause(mpd, YES);
		[self handleError: @"could not modify player state"];
	}
	[self postLock];
}


- (void) playPlaylistPosition: (unsigned int) pos
{
	[self preLock];
	@synchronized(self)
	{
		mpd_run_play_pos(mpd, pos);
		[self handleError: @"could not play queue song"];
	}
	[self postLock];
}

#pragma mark Singleton Stuff

static DPClient* sharedSingleton = nil;

+ (DPClient*) sharedClient
{
    if (sharedSingleton == nil) {
        sharedSingleton = [[super allocWithZone: NULL] init];
    }
    return sharedSingleton;
}

+ (id)allocWithZone:(NSZone *)zone
{
    return [self sharedClient];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain
{
    return self;
}

- (NSUInteger)retainCount
{
    return NSUIntegerMax;  //denotes an object that cannot be released
}

- (void)release
{
    //do nothing
}

- (id)autorelease
{
    return self;
}

@end
