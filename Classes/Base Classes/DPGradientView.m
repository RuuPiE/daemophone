// daemophone - an MPD client for iPad
// Copyright (C) 2010 Aaron Griffith
//
// This file is licensed under the GNU GPL v2. See
// the file "main.m" for details.

#import "DPGradientView.h"

@implementation DPGradientView

- (id) initWithFrame: (CGRect) frame
{
    if (self = [super initWithFrame: frame])
	{
		[self init];
    }
    return self;
}

- (id) initWithCoder: (NSCoder*) decoder
{
	if (self = [super initWithCoder: decoder])
	{
		[self init];
	}
	return self;
}

- (id) init
{
	size_t num_locations = 2;
	CGFloat locations[2] = { 0.0, 1.0 };
	CGFloat components[8] = {
		1.0, 1.0, 1.0, 0.90, // start color
		1.0, 1.0, 1.0, 0.00, // end color
	};
	
	CGColorSpaceRef rgbColorspace = CGColorSpaceCreateDeviceRGB();
	gradient = CGGradientCreateWithColorComponents(rgbColorspace, components, locations, num_locations);
	CGColorSpaceRelease(rgbColorspace);
	
	return self;
}

- (void) setBackgroundColor: (UIColor*) color
{
	if (CGColorGetAlpha(color.CGColor) == 0.0)
	{
		// skip this, it lies!
		// this is usually when a table cell is selected, but we want the gradient
		// to remain opaque
		return;
	}
	
	[super setBackgroundColor: color];
}

- (void) drawRect: (CGRect) rect
{
    CGContextRef c = UIGraphicsGetCurrentContext();
	
	CGColorRef bgColor = self.backgroundColor.CGColor;
	
	CGContextSetFillColorSpace(c, CGColorGetColorSpace(bgColor));
	//CGContextSetRGBFillColor(c, 1.0, 0.0, 0.0, 1.0);
	CGContextSetFillColorWithColor(c, bgColor);
	CGContextFillRect(c, rect);
	
	CGRect currentBounds = self.bounds;
	CGPoint topCenter = CGPointMake(CGRectGetMidX(currentBounds), 0.0f);
	CGPoint midCenter = CGPointMake(CGRectGetMidX(currentBounds), CGRectGetMaxY(currentBounds));
	CGContextDrawLinearGradient(c, gradient, topCenter, midCenter, 0);
}


- (void) dealloc
{
	CGGradientRelease(gradient);
    [super dealloc];
}

@end
