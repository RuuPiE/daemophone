// daemophone - an MPD client for iPad
// Copyright (C) 2010, 2011 Aaron Griffith
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

- (UITextField*) createTextField;
{
	/* create a reasonable text-entry field for use in a table cell */
	UITextField* field = [[UITextField alloc] initWithFrame: CGRectMake(20.0, 15.0, 300.0, 30.0)];
	
	/* nice defaults */
	[field setTextAlignment: UITextAlignmentRight];
	//[field setClearButtonMode: UITextFieldViewModeWhileEditing];
	[field setAutocapitalizationType: UITextAutocapitalizationTypeNone];
	[field setAutocorrectionType: UITextAutocorrectionTypeNo];
	[field setReturnKeyType: UIReturnKeyDone];
	
	[field setDelegate: self];
	
	return field;
}

- (void) viewDidLoad
{
    [super viewDidLoad];
	
	addressField = [self createTextField];
	[addressField setPlaceholder: @"localhost"];
	[addressField setKeyboardType: UIKeyboardTypeURL];
	
	portField = [self createTextField];
	[portField setPlaceholder: @"6600"]; // default mpd port
	[portField setKeyboardType: UIKeyboardTypeNumberPad];
	
	passwordField = [self createTextField];
	[passwordField setPlaceholder: @"(no password)"];
	[passwordField setSecureTextEntry: YES];
}

- (void) viewDidUnload
{
    [super viewDidUnload];
    
	self.settingsTableView = nil;
	
	if (addressField == nil)
	{
		[addressField release];
		addressField = nil;
	}
	if (portField == nil)
	{
		[portField release];
		portField = nil;
	}
	if (passwordField == nil)
	{
		[passwordField release];
		passwordField = nil;
	}
}

- (void) viewWillAppear: (BOOL) animated
{
	[mpclient setSettingsViewController: self];
}

- (void) viewDidDisappear: (BOOL) animated
{
	[mpclient setSettingsViewController: nil];
}

- (BOOL) shouldAutorotateToInterfaceOrientation: (UIInterfaceOrientation) interfaceOrientation
{
    // Overriden to allow any orientation.
    return YES;
}

- (void) dealloc
{
	if (addressField == nil)
	{
		[addressField release];
		addressField = nil;
	}
	if (portField == nil)
	{
		[portField release];
		portField = nil;
	}
	if (passwordField == nil)
	{
		[passwordField release];
		passwordField = nil;
	}
	
    [super dealloc];
}

#pragma mark update after new server info

- (void) updateServerInfo
{
	/* reset all our data */
	NSString* portstr;
	if (mpclient.port == 0)
	{
		portstr = [[NSString alloc] init];
	} else {
		portstr = [[NSString alloc] initWithFormat: @"%i", mpclient.port];
	}
	
	[portField setText: portstr];
	[portstr release];
	
	[addressField setText: [mpclient host]];
	[passwordField setText: [mpclient password]];
	
	// we may have changed connection state -- handle section fades
	
	NSIndexSet* indexSet = [[NSIndexSet alloc] initWithIndexesInRange: NSMakeRange(1, ESS_COUNT - 1)];
	if ([mpclient isConnected] && [settingsTableView numberOfSections] == 1)
	{
		[settingsTableView insertSections: indexSet withRowAnimation: UITableViewRowAnimationFade];
	} else if (![mpclient isConnected] && [settingsTableView numberOfSections] == ESS_COUNT) {
		[settingsTableView deleteSections: indexSet withRowAnimation: UITableViewRowAnimationFade];
	}
	[indexSet release];
}

- (void) updateOptions
{
	// just reload the options section, animations are a bit overkill here
	if ([settingsTableView numberOfSections] > ESS_PLAYMODES)
	{
		NSIndexSet* indexSet = [[NSIndexSet alloc] initWithIndex: ESS_PLAYMODES];
		[settingsTableView reloadSections: indexSet withRowAnimation: UITableViewRowAnimationNone];
		[indexSet release];
	}
}

- (void) updateOutputs
{
	NSMutableArray* switches = [[NSMutableArray alloc] init];
	
	if ([mpclient outputs] != nil)
	{
		for (NSDictionary* output in [mpclient outputs])
		{
			UISwitch* newSwitch = [[UISwitch alloc] initWithFrame: CGRectZero];
			[switches addObject: newSwitch];
			
			[newSwitch addTarget: self action: @selector(setOutput:) forControlEvents: UIControlEventValueChanged];
			[newSwitch setOn: [[output objectForKey: @"enabled"] boolValue]];
			
			[newSwitch release];
		}
	}
	
	if (outputSwitches != nil)
		[outputSwitches release];
	outputSwitches = switches;
	
	// just reload the options section, animations are a bit overkill here
	if ([settingsTableView numberOfSections] > ESS_OUTPUTS)
	{
		NSIndexSet* indexSet = [[NSIndexSet alloc] initWithIndex: ESS_OUTPUTS];
		[settingsTableView reloadSections: indexSet withRowAnimation: UITableViewRowAnimationNone];
		[indexSet release];
	}
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

- (void) setOutput: (UISwitch*) toggle
{
	NSInteger index = [outputSwitches indexOfObject: toggle];
	if (index == NSNotFound)
		return;
	unsigned int output_id = [[[[mpclient outputs] objectAtIndex: index] objectForKey: @"id"] unsignedIntValue];
	
	[mpclient setOutput: output_id on: toggle.on];
}

#pragma mark text field delegate

// for all of these, we assume text fields are only for server info

- (BOOL) textFieldShouldReturn: (UITextField*) textField
{
	[textField resignFirstResponder];
	return YES;
}

- (void) textFieldDidEndEditing: (UITextField*) textField
{
	// reconnect with new info
	unsigned int port = [portField.text integerValue];
	NSLog(@"using port %i", port);
	[mpclient disconnect];
	[mpclient connectToHost: addressField.text port: port password: passwordField.text];
}

#pragma mark Table View Data Source

- (NSInteger) numberOfSectionsInTableView: (UITableView*) tableView;
{
	if ([mpclient isConnected])
		return ESS_COUNT;
	return 1;
}

- (NSInteger) tableView: (UITableView*) tableView numberOfRowsInSection: (NSInteger) section
{
	switch (section)
	{
		case ESS_SERVERINFO:
			return ESI_COUNT;
		case ESS_PLAYMODES:
			return EPM_COUNT;
		case ESS_OUTPUTS:
			if (outputSwitches == nil)
				return 0;
			return [outputSwitches count];
	};
	return 0;
}

- (NSString*) tableView: (UITableView*) tableView titleForHeaderInSection: (NSInteger) section
{
	switch (section)
	{
		case ESS_SERVERINFO:
			return @"Server";
		case ESS_PLAYMODES:
			return @"Play Modes";
		case ESS_OUTPUTS:
			return @"Outputs";
	};
	return nil;
}

- (UITableViewCell*) tableView: (UITableView*) tableView cellForRowAtIndexPath: (NSIndexPath*) indexPath;
{
	UITableViewCell* cell = [self cellForTable: tableView withText: @"settings"];
	
	if ([indexPath section] == ESS_SERVERINFO)
	{
		switch ([indexPath row])
		{
			case ESI_ADDRESS:
				[cell.textLabel setText: @"Address"];
				[cell setAccessoryView: addressField];
				break;
			case ESI_PORT:
				[cell.textLabel setText: @"Port"];
				[cell setAccessoryView: portField];
				break;
			case ESI_PASSWORD:
				[cell.textLabel setText: @"Password"];
				[cell setAccessoryView: passwordField];
				break;
		};
		return cell;
	}
	
	// these next ones use toggles as an accessory view
	UISwitch* toggle = [[UISwitch alloc] initWithFrame: CGRectZero];
	[cell setAccessoryView: toggle];
	[toggle release];
	
	if ([indexPath section] == ESS_PLAYMODES)
	{
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
				label.opaque = NO;
				label.backgroundColor = [UIColor clearColor];
				[cell setAccessoryView: label];
				break;
		}
		
		return cell;
	}
	
	if ([indexPath section] == ESS_OUTPUTS && outputSwitches != nil)
	{
		[cell.textLabel setText: [[[mpclient outputs] objectAtIndex: [indexPath row]] objectForKey: @"name"]];
		[cell setAccessoryView: [outputSwitches objectAtIndex: [indexPath row]]];
		return cell;
	}
	
	// we should never get here, but just in case
	[cell release];
	
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
