// daemophone - an MPD client for iPad
// Copyright (C) 2010 Aaron Griffith
//
// This file is licensed under the GNU GPL v2. See
// the file "main.m" for details.

#import <UIKit/UIKit.h>

@interface daemophoneAppDelegate : NSObject <UIApplicationDelegate>
{
    UIWindow* window;
	UISplitViewController* splitview;
}

@property (nonatomic, retain) IBOutlet UIWindow* window;
@property (nonatomic, retain) IBOutlet UISplitViewController* splitview;

@end

