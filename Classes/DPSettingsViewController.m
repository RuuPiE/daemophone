// daemophone - an MPD client for iPad
// Copyright (C) 2010 Aaron Griffith
//
// This file is licensed under the GNU GPL v2. See
// the file "main.m" for details.

#import "DPSettingsViewController.h"


@implementation DPSettingsViewController

@synthesize settingsTableView;

- (id) initWithNibName: (NSString*) nibNameOrNil bundle: (NSBundle*) nibBundleOrNil
{
    if ((self = [super initWithNibName: nibNameOrNil bundle: nibBundleOrNil]))
	{
		self.modalPresentationStyle = UIModalPresentationFormSheet;
		self.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    }
    return self;
}

- (void) viewDidLoad
{
    [super viewDidLoad];
	[mpclient setSettingsViewController: self];
}

- (void) viewDidUnload
{
    [super viewDidUnload];
	[mpclient setSettingsViewController: nil];
    
	self.settingsTableView = nil;
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

- (void) dealloc
{
    [super dealloc];
}

#pragma mark update after new server info

- (void) updateOptions
{
	// just reload the table
	
	//NSRange range;
	//range.location = 0;
	//range.length = 1;
	//NSIndexSet* indexSet = [[NSIndexSet alloc] initWithIndexesInRange: range];
	//[settingsTableView reloadSections: indexSet withRowAnimation: UITableViewRowAnimationFade];
	//[indexSet release];
	
	[settingsTableView reloadData];
}

#pragma mark callbacks for settings controls

- (void) setRepeat: (UISwitch*) toggle
{
	[mpclient setRepeat: toggle.on];
}

- (void) setRandom: (UISwitch*) toggle
{
	[mpclient setRandom: toggle.on];
}

- (void) setSingle: (UISwitch*) toggle
{
	[mpclient setSingle: toggle.on];
}

- (void) setConsume: (UISwitch*) toggle
{
	[mpclient setConsume: toggle.on];
}


#pragma mark Table View Data Source

- (NSInteger) numberOfSectionsInTableView: (UITableView*) tableView;
{
	return ESS_COUNT;
}

- (NSInteger) tableView: (UITableView*) tableView numberOfRowsInSection: (NSInteger) section
{
	switch (section)
	{
		case ESS_PLAYMODES:
			return EPM_COUNT;
	};
	return 0;
}

- (NSString*) tableView: (UITableView*) tableView titleForHeaderInSection: (NSInteger) section
{
	switch (section)
	{
		case ESS_PLAYMODES:
			return @"Play Modes";
	};
	return nil;
}

- (UITableViewCell*) tableView: (UITableView*) tableView cellForRowAtIndexPath: (NSIndexPath*) indexPath;
{	
	if ([indexPath section] == ESS_PLAYMODES)
	{
		UITableViewCell* cell = [self cellForTable: tableView withText: @"settings"];
		UISwitch* toggle = [[UISwitch alloc] initWithFrame: CGRectZero];
		[cell setAccessoryView: toggle];
		[toggle release];
		
		switch ([indexPath row])
		{
			case EPM_REPEAT:
				[cell.textLabel setText: @"Repeat"];
				[toggle setOn: [mpclient repeat]];
				[toggle addTarget: self action: @selector(setRepeat:) forControlEvents: UIControlEventValueChanged];
				break;
			case EPM_SINGLE:
				[cell.textLabel setText: @"Single"];
				[toggle setOn: [mpclient single]];
				[toggle addTarget: self action: @selector(setSingle:) forControlEvents: UIControlEventValueChanged];
				break;
			case EPM_RANDOM:
				[cell.textLabel setText: @"Random"];
				[toggle setOn: [mpclient random]];
				[toggle addTarget: self action: @selector(setRandom:) forControlEvents: UIControlEventValueChanged];
				break;
			case EPM_CONSUME:
				[cell.textLabel setText: @"Consume"];
				[toggle setOn: [mpclient consume]];
				[toggle addTarget: self action: @selector(setConsume:) forControlEvents: UIControlEventValueChanged];
				break;
			case EPM_CROSSFADE:
				[cell.textLabel setText: @"Crossfade"];
				UILabel* label = [[UILabel alloc] initWithFrame: CGRectMake(0.0, 0.0, 200.0, 20.0)];
				if ([mpclient crossfade] == 0)
				{
					[label setText: @"off"];
				} else if ([mpclient crossfade] == 1)
				{
					[label setText: @"1 second"];
				} else {
					NSString* labelText = [[NSString alloc] initWithFormat: @"%i seconds", [mpclient crossfade]];
					[label setText: labelText];
					[labelText release];
				}
				[label setTextAlignment: UITextAlignmentRight];
				[cell setAccessoryView: label];
				break;
		}
		
		return cell;
	}
	
	return nil;
}

#pragma mark Table View Delegate

- (NSIndexPath*) tableView: (UITableView*) tableView willSelectRowAtIndexPath: (NSIndexPath*) indexPath
{
	// we have ONE exception: the crossfade control
	if ([indexPath section] == ESS_PLAYMODES && [indexPath row] == EPM_CROSSFADE)
		return indexPath;
	
	// don't be selecting any settings, now
	return nil;
}

- (void) tableView: (UITableView*) tableView didSelectRowAtIndexPath: (NSIndexPath*) indexPath
{
	// do our magick if this is the crossfade control
	if ([indexPath section] == ESS_PLAYMODES && [indexPath row] == EPM_CROSSFADE)
	{
		UIPickerView* control = [[UIPickerView alloc] initWithFrame: CGRectMake(0.0, 0.0, 200.0, 200.0)];
		control.delegate = self;
		control.dataSource = self;
		[control setShowsSelectionIndicator: YES];
		
		[control setBackgroundColor: [UIColor whiteColor]];
		[control setOpaque: YES];
		UIViewController* controller = [[UIViewController alloc] initWithNibName: nil bundle: nil];
		controller.view = control;
		
		UIPopoverController* popover = [[UIPopoverController alloc] initWithContentViewController: controller];
		
		popover.popoverContentSize = control.frame.size;
		popover.delegate = self;
		
		[controller release];
		[control release];
		
		// here's some hokey-pokey to make sure the popover is centered on the
		// actual content of the accessory view, not the whole rect
		UITableViewCell* selectedCell = [tableView cellForRowAtIndexPath: indexPath];
		CGRect rect = selectedCell.accessoryView.frame;
		CGSize fitSize = [selectedCell.accessoryView sizeThatFits: rect.size];
		// align right, valign center
		rect.origin.x += rect.size.width - fitSize.width;
		rect.origin.y += (rect.size.height - fitSize.height) / 2.0;
		rect.size = fitSize;
		
		[popover presentPopoverFromRect: rect inView: selectedCell permittedArrowDirections: UIPopoverArrowDirectionAny animated: YES];
		
		unsigned int crossfade = [mpclient crossfade];
		[control selectRow: crossfade inComponent: 0 animated: NO];
		[control selectRow: crossfade inComponent: 0 animated: NO];
		NSLog(@"selected row %i", crossfade);
		
		[tableView deselectRowAtIndexPath: indexPath animated: YES];
	}
}

#pragma mark Picker View delegate/data source

- (NSInteger) numberOfComponentsInPickerView: (UIPickerView*) pickerView
{
	return 1;
}

- (NSInteger) pickerView: (UIPickerView*) pickerView numberOfRowsInComponent: (NSInteger) component
{
	// up to 30s crossfade, and off = 31 options
	return 31;
}

- (NSString*) pickerView: (UIPickerView*) pickerView titleForRow: (NSInteger) row forComponent: (NSInteger) component
{
	if (row == 0)
		return @"off";
	if (row == 1)
		return @"1 second";
	
	// though I hate to use autorelease on iOS, there seems to be no other way
	return [[[NSString alloc] initWithFormat: @"%i seconds", row] autorelease];
}

- (void) pickerView: (UIPickerView*) pickerView didSelectRow: (NSInteger) row  inComponent: (NSInteger) component
{
	[mpclient setCrossfade: row];
}

#pragma mark Popover delegate methods

- (void) popoverControllerDidDismissPopover: (UIPopoverController*) popoverController
{
	[popoverController release];
}

#pragma mark IB actions

- (IBAction) dismissSettings: (id) button
{
	[self.parentViewController dismissModalViewControllerAnimated: YES];
}


@end
