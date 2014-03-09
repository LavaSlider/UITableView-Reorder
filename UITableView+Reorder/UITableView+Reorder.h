//
//  UITableView+Reorder.h
//
//
//  Created by David W. Stockton on 3/3/14.
//  Copyright (c) 2014 Syntonicity, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UITableView (Reorder)

@property (nonatomic) BOOL allowsLongPressToReorder;
@property (nonatomic) BOOL allowsLongPressToReorderDuringEditing;

// Add this method to your tableview datasource method to correct the number of
// rows in a section during an active move like this:
//	- (NSInteger) tableView: (UITableView *) tableView numberOfRowsInSection: (NSInteger) section {
//		NSInteger rowCount = [self.tableData[section] count];
//		rowCount = [tableView adjustedValueForReorderingOfRowCount: rowCount forSection: section];
//		return rowCount;
//	}
- (NSInteger) adjustedValueForReorderingOfRowCount: (NSInteger) rowCount forSection: (NSInteger) section;

// Use this method to translate the index path during an active move
- (NSIndexPath *) dataSourceIndexPathFromVisibleIndexPath: (NSIndexPath *) indexPath;

// Use this method to determine whether the empty place-holder cell should be returned.
- (BOOL) shouldSubstitutePlaceHolderForCellBeingMovedAtIndexPath: (NSIndexPath *) indexPath;

// If you want to connect your own gesture recognizer
// just set its target as the tableView and its action as:
- (void) rowReorderGesture: (UIGestureRecognizer *) gesture;

@end



@protocol UITableViewDataSourceReorderExtension <NSObject>
@optional
- (UIView *) tableView: (UITableView *) tableView snapShotViewOfCellAtIndexPath: (NSIndexPath *) indexPath;
@end



@protocol UITableViewDelegateReorderExtension <NSObject>
@optional
- (void) tableView: (UITableView *) tableView willMoveRowAtIndexPath: (NSIndexPath *) indexPath;
- (void) tableView: (UITableView *) tableView willMovePlaceHolderFromIndexPath: (NSIndexPath *) fromIndexPath toIndexPath: (NSIndexPath *) toIndexPath;
- (void) tableView: (UITableView *) tableView didMovePlaceHolderFromIndexPath: (NSIndexPath *) fromIndexPath toIndexPath: (NSIndexPath *) toIndexPath;
- (BOOL) cancelLongPressMoveResetsToOriginalState;
@end