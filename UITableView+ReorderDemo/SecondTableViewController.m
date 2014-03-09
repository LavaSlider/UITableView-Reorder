//
//  SecondTableViewController.m
//  UITableView+Reorder
//
//  Created by David W. Stockton on 3/4/14.
//  Copyright (c) 2014 Syntonicity. All rights reserved.
//

#import "SecondTableViewController.h"
#import "SettingsObject.h"
#define ENABLE_LONG_PRESS_MOVE
//#undef ENABLE_LONG_PRESS_MOVE
#ifdef ENABLE_LONG_PRESS_MOVE
#import "UITableView+Reorder.h"
#endif

@interface SecondTableViewController ()
@property (nonatomic, strong) NSMutableArray *tableData;
@end

@implementation SecondTableViewController

- (void) viewDidLoad {
	[super viewDidLoad];
	self.tableData = [NSMutableArray arrayWithObjects:
			  [NSMutableArray arrayWithObjects: @1, @2, @3, nil],
			  [NSMutableArray arrayWithObjects: @4, @5, @6, @7, nil],
			  [NSMutableArray arrayWithObjects: @8, nil],
			  [NSMutableArray arrayWithObjects: @9, @10, @11, nil],
			  [NSMutableArray arrayWithObjects: @12, @13, nil],
			  [NSMutableArray arrayWithObjects: @14, @15, @16, nil],
			  nil];
	
	// Add an Edit button in the navigation bar for this view controller
	// so comparison can be made to the built-in reordering.
	self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void) viewWillAppear: (BOOL) animated {
//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
#ifdef ENABLE_LONG_PRESS_MOVE
	SettingsObject *mso = [SettingsObject masterSettingsObject];
	self.tableView.allowsLongPressToReorder = mso.allowsLongPressToReorder;
	self.tableView.allowsLongPressToReorderDuringEditing = mso.allowsLongPressToReorderDuringEditing;
	[self.tableView reloadData];
#endif
//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
}

#pragma mark - UITableViewDataSource methods

- (NSInteger) numberOfSectionsInTableView: (UITableView *) tableView {
	NSInteger sectionCount = self.tableData.count;
	return sectionCount;
}

- (NSInteger) tableView: (UITableView *) tableView numberOfRowsInSection: (NSInteger) section {
	NSInteger rowCount = [self.tableData[section] count];
//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
#ifdef ENABLE_LONG_PRESS_MOVE
	rowCount = [tableView adjustedValueForReorderingOfRowCount: rowCount forSection: section];
#endif
//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
	return rowCount;
}

- (UITableViewCell *) tableView: (UITableView *) tableView cellForRowAtIndexPath: (NSIndexPath *) indexPath {
	static NSString *CellIdentifier = @"Cell";
//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
#ifdef ENABLE_LONG_PRESS_MOVE
	indexPath = [tableView dataSourceIndexPathFromVisibleIndexPath: indexPath];
#endif
//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifier];
	
	// Configure the cell...
//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
#ifdef ENABLE_LONG_PRESS_MOVE
	if( [tableView shouldSubstitutePlaceHolderForCellBeingMovedAtIndexPath: indexPath] ) {
		cell.textLabel.text = @"";
		return cell;
	}
#endif
//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
	cell.textLabel.text = [NSString stringWithFormat: @"Data element %@ (Section %d, row %d)",
			       self.tableData[indexPath.section][indexPath.row], indexPath.section, indexPath.row];
	return cell;
}

// Cannot remove or move rows that return NO from this method
//- (BOOL) tableView: (UITableView *) tableView canEditRowAtIndexPath: (NSIndexPath *) indexPath {
//	return NO;
//}

// Override to support conditional rearranging of the table view.
- (BOOL) tableView: (UITableView *) tableView canMoveRowAtIndexPath: (NSIndexPath *) indexPath {
	SettingsObject *mso = [SettingsObject masterSettingsObject];
	if( mso.canOnlyMoveEvenNumberedRows && mso.canOnlyMoveRowsFromEvenNumberedSections ) {
		if( (indexPath.row & 0x01) == 0 && (indexPath.section & 0x01) == 0 )
			return YES;
		return NO;
	} else if( mso.canOnlyMoveEvenNumberedRows ) {
		if( (indexPath.row & 0x01) == 0 )
			return YES;
		return NO;
	} else if( mso.canOnlyMoveRowsFromEvenNumberedSections ) {
		if( (indexPath.section & 0x01) == 0 )
			return YES;
		return NO;
	}
	return YES;
}

// Override to support rearranging the table view.
- (void) tableView: (UITableView *) tableView moveRowAtIndexPath: (NSIndexPath *) fromIndexPath toIndexPath: (NSIndexPath *) toIndexPath {
	NSLog( @"Request to move %d,%d to %d,%d", fromIndexPath.row, fromIndexPath.section, toIndexPath.row, toIndexPath.section );
	NSLog( @"- Data before move:" );
	[self.tableData enumerateObjectsUsingBlock: ^( id obj, NSUInteger idx, BOOL *stop ) {
		NSLog( @"  %2d: %@", idx, [obj componentsJoinedByString: @","] );
	}];
	id buffer = [self.tableData[fromIndexPath.section] objectAtIndex: fromIndexPath.row];
	[self.tableData[fromIndexPath.section] removeObjectAtIndex: fromIndexPath.row];
	[self.tableData[toIndexPath.section] insertObject: buffer atIndex: toIndexPath.row];
	NSLog( @"- Data After move:" );
	[self.tableData enumerateObjectsUsingBlock: ^( id obj, NSUInteger idx, BOOL *stop ) {
		NSLog( @"  %2d: %@", idx, [obj componentsJoinedByString: @","] );
	}];
}

- (void) tableView: (UITableView *) tableView commitEditingStyle: (UITableViewCellEditingStyle) editingStyle forRowAtIndexPath: (NSIndexPath *) indexPath {
	if( editingStyle == UITableViewCellEditingStyleDelete ) {
		[self.tableData[indexPath.section] removeObjectAtIndex: indexPath.row];
		[tableView deleteRowsAtIndexPaths: @[indexPath] withRowAnimation: UITableViewRowAnimationFade];
	}
}

#pragma mark - UITableViewDelegate methods

- (CGFloat) tableView: (UITableView *) tableView heightForRowAtIndexPath: (NSIndexPath *) indexPath {
//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
#ifdef ENABLE_LONG_PRESS_MOVE
	indexPath = [tableView dataSourceIndexPathFromVisibleIndexPath: indexPath];
#endif
//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
	CGFloat	height = 44.0;
	SettingsObject *mso = [SettingsObject masterSettingsObject];
	if( mso.useVariableRowHeights ) {
		NSNumber *datum = self.tableData[indexPath.section][indexPath.row];
		if( ([datum integerValue] % 3) == 0 )
			height = 79.0;
		else if( ([datum integerValue] % 3) == 1 )
			height = 27.0;
	}
	return height;
}

- (NSIndexPath *) tableView: (UITableView *) tableView targetIndexPathForMoveFromRowAtIndexPath: (NSIndexPath *) sourceIndexPath toProposedIndexPath: (NSIndexPath *) proposedDestinationIndexPath {
	SettingsObject *mso = [SettingsObject masterSettingsObject];
	if( mso.canOnlyMoveToEvenNumberedSections && (proposedDestinationIndexPath.section & 0x01) ) {
		return sourceIndexPath;
	}
	if( mso.canOnlyMoveToEvenNumberedRows && (proposedDestinationIndexPath.row & 0x01) ) {
		return sourceIndexPath;
	}
	return proposedDestinationIndexPath;
}

@end
