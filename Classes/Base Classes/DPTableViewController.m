// daemophone - an MPD client for iPad
// Copyright (C) 2010 Aaron Griffith
//
// This file is licensed under the GNU GPL v2. See
// the file "main.m" for details.

#import "DPTableViewController.h"

@implementation DPTableViewController

@synthesize newCell;

- (UITableViewCell*) cellForTable: (UITableView*) tableView withIdentifier: (NSString*) cellIdentifier
{
	UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier: cellIdentifier];
	if (cell)
	{
		return cell;
	}
	
	if ([cellIdentifier isEqual: @"UITableViewCell"])
	{
		return [[[UITableViewCell alloc] initWithStyle: UITableViewCellStyleDefault reuseIdentifier: cellIdentifier] autorelease];
	}
	
	[[NSBundle mainBundle] loadNibNamed: cellIdentifier owner: self options: nil];
	cell = newCell;
	[self setNewCell: nil];
	
	return cell;
}


- (UITableViewCell*) cellForTable: (UITableView*) tableView withText: (NSString*) text
{
	UITableViewCell* cell = [self cellForTable: tableView withIdentifier: @"UITableViewCell"];
	[cell setAccessoryView: nil];
	[cell setAccessoryType: UITableViewCellAccessoryDisclosureIndicator];
	[cell.textLabel setText: text];
	return cell;
}


- (UITableViewCell*) playlistCellForTable: (UITableView*) tableView withData: (NSDictionary*) data isActive: (BOOL) playing
{
	// tags and their info
	// 1 - (UILabel) Title
	// 2 - (UILabel) Album
	// 3 - (UILabel) Artist
	// 4 - (UIImageView) Now Playing Dingus
	// 5 - (UIView) background view (gradient!)
	UITableViewCell* cell = [self cellForTable: tableView withIdentifier: @"DPPlaylistCell"];
	
	UILabel* tmp;
	
	tmp = (UILabel*)[cell viewWithTag: 1];
	[tmp setText: [data objectForKey: @"title"]];

	tmp = (UILabel*)[cell viewWithTag: 2];
	[tmp setText: [data objectForKey: @"album"]];
	
	tmp = (UILabel*)[cell viewWithTag: 3];
	[tmp setText: [data objectForKey: @"artist"]];
	
	UIView* playdingus = [cell viewWithTag: 4];
	[playdingus setHidden: !playing];
	
	UIView* background = [cell viewWithTag: 5];
	if (playing)
	{
		[background setHidden: NO];
		
		UIColor* color;
		color = [[UIColor alloc] initWithWhite: 0.8 alpha: 1.0];
		[background setBackgroundColor: color];
		[color release];
	} else {
		[background setHidden: YES];
	}
	
	return cell;
}

@end
