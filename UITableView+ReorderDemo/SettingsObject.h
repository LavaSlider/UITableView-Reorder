//
//  SettingsObject.h
//  UITableView+Reorder
//
//  Created by David W. Stockton on 3/5/14.
//  Copyright (c) 2014 Syntonicity. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SettingsObject : NSObject

+ (SettingsObject *) masterSettingsObject;

@property (nonatomic) BOOL allowsLongPressToReorder;
@property (nonatomic) BOOL allowsLongPressToReorderDuringEditing;

@property (nonatomic) BOOL useVariableRowHeights;

@property (nonatomic) BOOL canOnlyMoveRowsFromEvenNumberedSections;
@property (nonatomic) BOOL canOnlyMoveEvenNumberedRows;

@property (nonatomic) BOOL canOnlyMoveToEvenNumberedSections;
@property (nonatomic) BOOL canOnlyMoveToEvenNumberedRows;

@end
