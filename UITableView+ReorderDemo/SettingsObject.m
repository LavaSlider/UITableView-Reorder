//
//  SettingsObject.m
//  UITableView+Reorder
//
//  Created by David W. Stockton on 3/5/14.
//  Copyright (c) 2014 Syntonicity. All rights reserved.
//

#import "SettingsObject.h"

static SettingsObject *_masterSettingsObject = nil;

@implementation SettingsObject

+ (SettingsObject *) masterSettingsObject {
	if( !_masterSettingsObject ) {
		_masterSettingsObject = [[SettingsObject alloc] init];

		// Set the default statuses
		_masterSettingsObject.allowsLongPressToReorder = YES;
		_masterSettingsObject.useVariableRowHeights = YES;
	}
	return _masterSettingsObject;
}

@end
