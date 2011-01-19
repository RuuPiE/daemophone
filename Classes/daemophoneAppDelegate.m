//
// daemophone - an MPD client for iPad
// Copyright (C) 2010, 2011 Aaron Griffith
//
// This file is licensed under the GNU GPL v2. See
// the file "main.m" for details.

#import "daemophoneAppDelegate.h"

@implementation daemophoneAppDelegate

@synthesize window;
@synthesize splitview;

- (BOOL) application: (UIApplication*) application didFinishLaunchingWithOptions: (NSDictionary*) launchOptions
{    
	
    // Override point for customization after application launch
	
	[window addSubview: splitview.view];
    [window makeKeyAndVisible];
	
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	NSString* host = [defaults stringForKey: @"host"];
	unsigned int port = [defaults integerForKey: @"port"];
	NSString* password = [defaults stringForKey: @"password"];
	
	if (host)
	{
		[mpclient connectToHost: host port: port password: password];
	}
    
    return YES;
}

- (void) applicationWillTerminate: (UIApplication*) application
{	
	[mpclient disconnect];
	[splitview release];
    [window release];
}


@end
