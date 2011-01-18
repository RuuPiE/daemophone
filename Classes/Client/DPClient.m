// daemophone - an MPD client for iPad
// Copyright (C) 2010, 2011 Aaron Griffith
//
// This file is licensed under the GNU GPL v2. See
// the file "main.m" for details.

#import "DPClient.h"

#import "DPPlaylistViewController.h"
#import "DPSettingsViewController.h"

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

@synthesize host, port, password;
@synthesize needInterruptNumber;
@synthesize currentSongInfo, nextSongInfo;
@synthesize currentSongLength, currentSongPosition, isPlaying, isPaused;
@synthesize playlist, currentSongPlaylistPosition;
@synthesize repeat, random, single, consume, crossfade;
@synthesize outputs;

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

- (void) updateOptions
{	
	// player options - crossfade, repeat, ...
	if (mpd)
	{
		@synchronized(self)
		{
			struct mpd_status* status = mpd_run_status(mpd);
			if ([self handleError: @"could not get status"])
				return;
			
			repeat = mpd_status_get_repeat(status);
			random = mpd_status_get_random(status);
			single = mpd_status_get_single(status);
			consume = mpd_status_get_consume(status);
			crossfade = mpd_status_get_crossfade(status);
			
			mpd_status_free(status);
		}
	}
	
	if (settingsViewController != nil)
	{
		[settingsViewController performSelectorOnMainThread: @selector(updateOptions) withObject: nil waitUntilDone: NO];
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

- (void) updateOutputs
{
	if (outputs)
		[outputs release];
	
	if (mpd)
	{
		NSMutableArray* mutableOutputs = [[NSMutableArray alloc] init];
		
		@synchronized(self)
		{
			struct mpd_output* output;
			mpd_send_outputs(mpd);
			
			while (output = mpd_recv_output(mpd))
			{
				NSMutableDictionary* mutableOutput = [[NSMutableDictionary alloc] init];
				NSString* tmps;
				NSNumber* tmpn;
				
				tmpn = [[NSNumber alloc] initWithUnsignedInt: mpd_output_get_id(output)];
				[mutableOutput setObject: tmpn forKey: @"id"];
				[tmpn release];
				
				tmpn = [[NSNumber alloc] initWithBool: mpd_output_get_enabled(output)];
				[mutableOutput setObject: tmpn forKey: @"enabled"];
				[tmpn release];
				
				tmps = [[NSString alloc] initWithUTF8String: mpd_output_get_name(output)];
				[mutableOutput setObject: tmps forKey: @"name"];
				[tmps release];
				
				[mutableOutputs addObject: mutableOutput];
				[mutableOutput release];
				mpd_output_free(output);
			}
			
			if ([self handleError: @"could not get outputs"])
			{
				[mutableOutputs release];
				return;
			}
		}
		
		outputs = mutableOutputs;
	} else {
		outputs = nil;
	}
	
	if (settingsViewController != nil)
	{
		[settingsViewController performSelectorOnMainThread: @selector(updateOutputs) withObject: nil waitUntilDone: NO];
	}
}

/* just updates to host, port, connection status ... */
- (void) updateServerInfo
{
	if (settingsViewController != nil)
	{
		[settingsViewController performSelectorOnMainThread: @selector(updateServerInfo) withObject: nil waitUntilDone: NO];
	}
	
	if (fileBrowserViewController != nil)
	{
		[fileBrowserViewController performSelectorOnMainThread: @selector(updateServerInfo) withObject: nil waitUntilDone: NO];
	}
}

- (void) updateAll
{
	// do NOT update server info -- that is handled specially
	
	// player can use info from the queue, so update queue before player
	[self updateQueue];
	[self updatePlayer];
	[self updateOptions];
	[self updateOutputs];
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
	if (playlistViewController == nil)
		return;
	[playlistViewController retain];
	
	// update the controller
	[playlistViewController updateCurrentSong];
	[playlistViewController updateCurrentSongPosition];
	[playlistViewController updateControls];
}

- (DPSettingsViewController*) settingsViewController
{
	return settingsViewController;
}

- (void) setSettingsViewController: (DPSettingsViewController*) svc
{
	if (settingsViewController != nil)
		[settingsViewController release];
	settingsViewController = svc;
	if (settingsViewController == nil)
		return;
	[settingsViewController retain];
	
	// update the controller
	[settingsViewController updateServerInfo];
	[settingsViewController updateOptions];
	[settingsViewController updateOutputs];
}

- (DPFileBrowserViewController*) fileBrowserViewController
{
	return fileBrowserViewController;
}

- (void) setFileBrowserViewController: (DPFileBrowserViewController*) fbvc
{
	if (fileBrowserViewController != nil)
		[fileBrowserViewController release];
	fileBrowserViewController = fbvc;
	if (fileBrowserViewController == nil)
		return;
	[fileBrowserViewController retain];
	
	// update the controller
	[fileBrowserViewController updateServerInfo];
}

- (void) dealloc
{
	[self disconnect];
	
	self.playlistViewController = nil;
	self.settingsViewController = nil;
	self.fileBrowserViewController = nil;
	
	if (currentSongInfo != nil)
		[currentSongInfo release];
	
	if (nextSongInfo != nil)
		[nextSongInfo release];
	
	if (playlist != nil)
		[playlist release];
	
	if (outputs != nil)
		[outputs release];
	
	[super dealloc];
}

#pragma mark idle thread

- (void) idleThreadSelector: (id) unused
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	// setup
	NSLog(@"mpd idle: thread started");
	[self updateAll];
	[self updateServerInfo];
	
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
		
		if (events & MPD_IDLE_QUEUE)
		{
			// update queue *and* player -- player handles currently playing queue item
			[self updateQueue];
			
			// if we have a player update, skip this (we do it later)
			if (!(events & MPD_IDLE_PLAYER))
				[self updatePlayer];
		}
		if (events & MPD_IDLE_PLAYER)
			[self updatePlayer];
		if (events & MPD_IDLE_OPTIONS)
			[self updateOptions];
		if (events & MPD_IDLE_OUTPUT)
			[self updateOutputs];
		
		//NSLog(@"needInterrupt delay begin %i", needInterruptNumber);
		while ([self needInterrupt])
			[NSThread sleepForTimeInterval: MPD_IDLE_INTERVALS / 1000.0];
		//NSLog(@"needInterrupt delay end");
		
		// pool maintainance
		[pool release];
		pool = [[NSAutoreleasePool alloc] init];
	}
	
	// teardown (don't trust mpd, may be that mpd == NULL)
	NSLog(@"mpd idle: thread stopping");
	
	[pool release];
}

#pragma mark connection managing

- (BOOL) connectToHost: (NSString*) _host port: (unsigned int) _port
{
	return [self connectToHost: _host port: _port password: nil];
}

- (BOOL) connectToHost: (NSString*) _host port: (unsigned int) _port password: (NSString*) _password;
{
	@synchronized(self)
	{
		if (mpd != NULL)
			[self disconnect];
		
		// set data NOW so failure still has last attempt data
		if (host)
			[host release];
		if (password)
			[password release];
		
		host = [_host copy];
		port = _port;
		if (_password)
		{
			password = [_password copy];
		} else {
			password = [[NSString alloc] init];
		}
		
		// connect
		mpd = mpd_connection_new([_host cStringUsingEncoding: NSUTF8StringEncoding], _port, MPD_TIMEOUT);
		
		if ([self handleError: @"could not connect"])
			return NO;
		
		if (_password && [_password length] != 0)
		{
			// use a password
			mpd_run_password(mpd, [_password cStringUsingEncoding: NSUTF8StringEncoding]);
			if ([self handleError: @"password failed"])
				return NO;
		}
		
		const unsigned int* version = mpd_connection_get_server_version(mpd);
		NSLog(@"mpd: connected to %@:%i, protocol version %i.%i.%i", _host, _port, version[0], version[1], version[2]);
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
		{
			[self postLock];
			return;
		}
	}
	[self postLock];
	
	if ([NSThread currentThread] != idleThread && idleThread != nil)
	{
		[idleThread cancel];
		while (![idleThread isFinished]) [NSThread sleepForTimeInterval: 0.1];
	}
	
	@synchronized(self)
	{
		mpd_connection_free(mpd);
		mpd = NULL;
		
		if (idleThread)
		{
			[idleThread release];
			idleThread = nil;
		}
		
		// do NOT update server info -- let the UI use the old info as long as it can
		// blanks are NOT helpful
		
		//if (host)
		//	[host release];
		//host = nil;
		//if (password)
		//	[password release];
		//password = nil;
		//port = 0;
		
		NSLog(@"mpd: disconnected");
		
	}
	
	[self updateServerInfo];
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
			NSString* errorstr = [[NSString alloc] initWithFormat: @"%@: %s", part, mpd_connection_get_error_message(mpd)];
			
			// log the error
			NSLog(@"mpd error: %@", errorstr);
			
			// whether to open settings menu (delayed, so we're disconnected when we show it)
			BOOL open_settings = NO;
			
			// check for misconfiguration (first time, data reset, ...)
			if (host == nil || [host length] == 0)
			{
				// display a helpful message
				UIAlertView* alert = [[UIAlertView alloc] initWithTitle: @"Configure a Server" message: @"You must configure a server for daemophone to use." delegate: nil cancelButtonTitle: @"OK" otherButtonTitles: nil];
				[alert show];
				[alert release];
				
				// open the configuration pane automatically
				open_settings = YES;
			} else {
				// display a message
				UIAlertView* alert = [[UIAlertView alloc] initWithTitle: @"MPD Error" message: errorstr delegate: nil cancelButtonTitle: @"OK" otherButtonTitles: nil];
				[alert show];
				[alert release];
			}
			
			[errorstr release];
			
			// disconnect if fatal
			if (mpd_connection_clear_error(mpd) == NO)
				[self disconnect];
			
			// open settings pane if we need to (and can)
			if (open_settings && playlistViewController != nil)
				[playlistViewController showSettings: nil];
			
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
		tmp = [[NSString alloc] initWithUTF8String: tmpc];
		[info setObject: tmp forKey: @"artist"];
		[tmp release];
	}
	
	tmpc = mpd_song_get_tag(song, MPD_TAG_ALBUM, 0);
	if (tmpc != NULL)
	{
		tmp = [[NSString alloc] initWithUTF8String: tmpc];
		[info setObject: tmp forKey: @"album"];
		[tmp release];
	}
	
	tmpc = mpd_song_get_tag(song, MPD_TAG_TITLE, 0);
	if (tmpc != NULL)
	{
		tmp = [[NSString alloc] initWithUTF8String: tmpc];
		[info setObject: tmp forKey: @"title"];
		[tmp release];
	}
	
	tmpc = mpd_song_get_uri(song);
	if (tmpc != NULL)
	{
		tmp = [[NSString alloc] initWithUTF8String: tmpc];
		[info setObject: tmp forKey: @"uri"];
		// use this for title also, if we have to
		if (![[info allKeys] containsObject: @"title"])
			[info setObject: tmp forKey: @"title"];
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

- (void) clearPlaylist
{
	[self preLock];
	@synchronized(self)
	{
		mpd_run_clear(mpd);
		[self handleError: @"could not clear queue"];
	}
	[self postLock];
}

- (void) addSong: (NSString*) uri
{
	[self preLock];
	@synchronized(self)
	{
		mpd_run_add(mpd, [uri cStringUsingEncoding: NSUTF8StringEncoding]);
		[self handleError: @"could not add song to queue"];
	}
	[self postLock];
}

#pragma mark player option setting

- (void) setRepeat: (BOOL) mode
{
	[self preLock];
	@synchronized(self)
	{
		mpd_run_repeat(mpd, mode);
		[self handleError: @"could not modify repeat mode"];
	}
	[self postLock];
}

- (void) setRandom: (BOOL) mode
{
	[self preLock];
	@synchronized(self)
	{
		mpd_run_random(mpd, mode);
		[self handleError: @"could not modify random mode"];
	}
	[self postLock];
}

- (void) setSingle: (BOOL) mode
{
	[self preLock];
	@synchronized(self)
	{
		mpd_run_single(mpd, mode);
		[self handleError: @"could not modify single mode"];
	}
	[self postLock];
}

- (void) setConsume: (BOOL) mode
{
	[self preLock];
	@synchronized(self)
	{
		mpd_run_consume(mpd, mode);
		[self handleError: @"could not modify consume mode"];
	}
	[self postLock];
}

- (void) setCrossfade: (unsigned int) length
{
	[self preLock];
	@synchronized(self)
	{
		mpd_run_crossfade(mpd, length);
		[self handleError: @"could not modify crossfade length"];
	}
	[self postLock];
}

#pragma mark database getters

- (NSArray*) getFiles: (NSString*) path
{
	NSMutableArray* ret = nil;
	
	[self preLock];
	@synchronized(self)
	{
		if (mpd == NULL)
		{
			[self postLock];
			return nil;
		}
		
		mpd_send_list_meta(mpd, [path cStringUsingEncoding: NSUTF8StringEncoding]);
		if ([self handleError: @"could not query database"])
		{
			[self postLock];
			return nil;
		}
		
		struct mpd_entity* entity;
		ret = [[NSMutableArray alloc] init];
		
		while ((entity = mpd_recv_entity(mpd)) != NULL)
		{
			const struct mpd_song* song;
			const struct mpd_directory* dir;
			const struct mpd_playlist* pl;
			
			NSString* path;
			
			NSMutableDictionary* retadd = [[NSMutableDictionary alloc] init];
			
			switch (mpd_entity_get_type(entity))
			{
				case MPD_ENTITY_TYPE_SONG:
					song = mpd_entity_get_song(entity);
					[retadd setObject: @"song" forKey: @"type"];
					
					path = [[NSString alloc] initWithUTF8String: mpd_song_get_uri(song)];
					[retadd setObject: path forKey: @"path"];
					[path release];
					
					break;
				case MPD_ENTITY_TYPE_DIRECTORY:
					dir = mpd_entity_get_directory(entity);
					[retadd setObject: @"directory" forKey: @"type"];
					
					path = [[NSString alloc] initWithUTF8String: mpd_directory_get_path(dir)];
					[retadd setObject: path forKey: @"path"];
					[path release];
					
					break;
				case MPD_ENTITY_TYPE_PLAYLIST:
					pl = mpd_entity_get_playlist(entity);
					[retadd setObject: @"playlist" forKey: @"type"];
					
					path = [[NSString alloc] initWithUTF8String: mpd_playlist_get_path(pl)];
					[retadd setObject: path forKey: @"path"];
					[path release];
					
					break;
				case MPD_ENTITY_TYPE_UNKNOWN:
				default:
					/* default -- do nothing! */
					break;
			};
			
			if ([[retadd allKeys] containsObject: @"path"])
			{
				// add the last path component too
				
				// this is autoreleased (ughh)
				NSString* lastpath = [(NSString*)[retadd objectForKey: @"path"] lastPathComponent];
				[retadd setObject: lastpath forKey: @"lastpath"];
			}
			
			[ret addObject: retadd];
			[retadd release];
			
			mpd_entity_free(entity);
		}
		
		mpd_response_finish(mpd);
		if ([self handleError: @"could not query database"])
		{
			[self postLock];
			[ret release];
			return nil;
		}
	}
	[self postLock];
	
	return ret;
}

#pragma mark Output Control

- (void) setOutput: (unsigned int) output_id on: (BOOL) on
{
	[self preLock];
	@synchronized(self)
	{
		if (on)
			mpd_run_enable_output(mpd, output_id);
		else
			mpd_run_disable_output(mpd, output_id);
		[self handleError: @"could not set output state"];
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
