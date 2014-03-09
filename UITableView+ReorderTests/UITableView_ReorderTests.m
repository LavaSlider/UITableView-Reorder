//
//  UITableView_ReorderTests.m
//  UITableView+ReorderTests
//
//  Created by David W. Stockton on 3/4/14.
//  Copyright (c) 2014 Syntonicity. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "UITableView+Reorder.h"

@interface UITableView_ReorderTests : XCTestCase

@end

@interface NSIndexPath (ReorderTestableMethods)
- (BOOL) isBelowRowAtIndexPath: (NSIndexPath *) referencePath;
- (BOOL) isAboveRowAtIndexPath: (NSIndexPath *) referencePath;
@end

@interface UITableView (ReorderTestableMethods)
@property (nonatomic) CGPoint reorderTouchOffset;
@property (nonatomic) CGFloat reorderAutoScrollRate;
@property (nonatomic, strong) NSIndexPath *fromIndexPathOfRowBeingMoved;
@property (nonatomic, strong) NSIndexPath *toIndexPathForRowBeingMoved;
@property (nonatomic, strong) UIView *snapShotOfCellBeingMoved;
@property (nonatomic, strong) CADisplayLink *reorderAutoScrollTimer;
@property (nonatomic, strong) UILongPressGestureRecognizer *rowReorderGestureRecognizer;
@property (nonatomic, strong) id <UIGestureRecognizerDelegate> delegateForRowReorderGestureRecognizer;

//- (NSIndexPath *) dataSourceIndexPathFromVisibleIndexPath: (NSIndexPath *) indexPath;
//- (BOOL) shouldSubstitutePlaceHolderForCellBeingMovedAtIndexPath: (NSIndexPath *) indexPath;
//- (NSInteger) adjustedValueForReorderingOfRowCount: (NSInteger) rowCount forSection: (NSInteger) section;

@end

@implementation UITableView_ReorderTests

- (void) setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void) tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

//------------------------------------------------------------------------------
// Test the trivial extensions added to NSIndexPath
- (void) test_NSIndexPathIsAboveRowAtIndexPath {
	NSIndexPath	*rowA;
	NSIndexPath	*rowB;

	rowA = [NSIndexPath indexPathForRow: 0 inSection: 0];
	XCTAssertFalse( [rowA isAboveRowAtIndexPath: nil], @"Row %d,%d cannot be above nil", rowA.section, rowA.row );
	rowB = [NSIndexPath indexPathForRow: 0 inSection: 0];
	XCTAssertFalse( [rowA isAboveRowAtIndexPath: rowB], @"Row %d,%d should not be above %d,%d", rowA.section, rowA.row, rowB.section, rowB.row );
	rowB = [NSIndexPath indexPathForRow: 1 inSection: 0];
	XCTAssertTrue( [rowA isAboveRowAtIndexPath: rowB], @"Row %d,%d should be above %d,%d", rowA.section, rowA.row, rowB.section, rowB.row );
	rowB = [NSIndexPath indexPathForRow: 0 inSection: 1];
	XCTAssertTrue( [rowA isAboveRowAtIndexPath: rowB], @"Row %d,%d should be above %d,%d", rowA.section, rowA.row, rowB.section, rowB.row );
	rowB = [NSIndexPath indexPathForRow: 1 inSection: 1];
	XCTAssertTrue( [rowA isAboveRowAtIndexPath: rowB], @"Row %d,%d should be above %d,%d", rowA.section, rowA.row, rowB.section, rowB.row );

	rowA = [NSIndexPath indexPathForRow: 2 inSection: 3];
	XCTAssertFalse( [rowA isAboveRowAtIndexPath: nil], @"Row %d,%d cannot be above nil", rowA.section, rowA.row );
	rowB = [NSIndexPath indexPathForRow: 0 inSection: 0];
	XCTAssertFalse( [rowA isAboveRowAtIndexPath: rowB], @"Row %d,%d should not be above %d,%d", rowA.section, rowA.row, rowB.section, rowB.row );
	rowB = [NSIndexPath indexPathForRow: 1 inSection: 0];
	XCTAssertFalse( [rowA isAboveRowAtIndexPath: rowB], @"Row %d,%d should not be above %d,%d", rowA.section, rowA.row, rowB.section, rowB.row );
	rowB = [NSIndexPath indexPathForRow: 0 inSection: 1];
	XCTAssertFalse( [rowA isAboveRowAtIndexPath: rowB], @"Row %d,%d should not be above %d,%d", rowA.section, rowA.row, rowB.section, rowB.row );
	rowB = [NSIndexPath indexPathForRow: 2 inSection: 3];
	XCTAssertFalse( [rowA isAboveRowAtIndexPath: rowB], @"Row %d,%d should not be above %d,%d", rowA.section, rowA.row, rowB.section, rowB.row );
	rowB = [NSIndexPath indexPathForRow: 3 inSection: 3];
	XCTAssertTrue( [rowA isAboveRowAtIndexPath: rowB], @"Row %d,%d should be above %d,%d", rowA.section, rowA.row, rowB.section, rowB.row );
	rowB = [NSIndexPath indexPathForRow: 0 inSection: 4];
	XCTAssertTrue( [rowA isAboveRowAtIndexPath: rowB], @"Row %d,%d should be above %d,%d", rowA.section, rowA.row, rowB.section, rowB.row );
	rowB = [NSIndexPath indexPathForRow: 3 inSection: 4];
	XCTAssertTrue( [rowA isAboveRowAtIndexPath: rowB], @"Row %d,%d should be above %d,%d", rowA.section, rowA.row, rowB.section, rowB.row );
}

- (void) test_NSIndexPathIsBelowRowAtIndexPath {
	NSIndexPath	*rowA;
	NSIndexPath	*rowB;
	
	rowA = [NSIndexPath indexPathForRow: 1 inSection: 1];
	XCTAssertFalse( [rowA isBelowRowAtIndexPath: nil], @"Row %d,%d cannot be below nil", rowA.section, rowA.row );
	rowB = [NSIndexPath indexPathForRow: 1 inSection: 1];
	XCTAssertFalse( [rowA isBelowRowAtIndexPath: rowB], @"Row %d,%d should not be below %d,%d", rowA.section, rowA.row, rowB.section, rowB.row );
	rowB = [NSIndexPath indexPathForRow: 1 inSection: 0];
	XCTAssertTrue( [rowA isBelowRowAtIndexPath: rowB], @"Row %d,%d should be below %d,%d", rowA.section, rowA.row, rowB.section, rowB.row );
	rowB = [NSIndexPath indexPathForRow: 0 inSection: 1];
	XCTAssertTrue( [rowA isBelowRowAtIndexPath: rowB], @"Row %d,%d should be below %d,%d", rowA.section, rowA.row, rowB.section, rowB.row );
	rowB = [NSIndexPath indexPathForRow: 0 inSection: 0];
	XCTAssertTrue( [rowA isBelowRowAtIndexPath: rowB], @"Row %d,%d should be below %d,%d", rowA.section, rowA.row, rowB.section, rowB.row );
	
	rowA = [NSIndexPath indexPathForRow: 2 inSection: 3];
	XCTAssertFalse( [rowA isBelowRowAtIndexPath: nil], @"Row %d,%d cannot be below nil", rowA.section, rowA.row );
	rowB = [NSIndexPath indexPathForRow: 2 inSection: 3];
	XCTAssertFalse( [rowA isBelowRowAtIndexPath: rowB], @"Row %d,%d should not be below %d,%d", rowA.section, rowA.row, rowB.section, rowB.row );
	rowB = [NSIndexPath indexPathForRow: 3 inSection: 3];
	XCTAssertFalse( [rowA isBelowRowAtIndexPath: rowB], @"Row %d,%d should not be below %d,%d", rowA.section, rowA.row, rowB.section, rowB.row );
	rowB = [NSIndexPath indexPathForRow: 0 inSection: 4];
	XCTAssertFalse( [rowA isBelowRowAtIndexPath: rowB], @"Row %d,%d should not be below %d,%d", rowA.section, rowA.row, rowB.section, rowB.row );
	rowB = [NSIndexPath indexPathForRow: 2 inSection: 4];
	XCTAssertFalse( [rowA isBelowRowAtIndexPath: rowB], @"Row %d,%d should not be below %d,%d", rowA.section, rowA.row, rowB.section, rowB.row );
	rowB = [NSIndexPath indexPathForRow: 3 inSection: 2];
	XCTAssertTrue( [rowA isBelowRowAtIndexPath: rowB], @"Row %d,%d should be below %d,%d", rowA.section, rowA.row, rowB.section, rowB.row );
	rowB = [NSIndexPath indexPathForRow: 0 inSection: 3];
	XCTAssertTrue( [rowA isBelowRowAtIndexPath: rowB], @"Row %d,%d should be below %d,%d", rowA.section, rowA.row, rowB.section, rowB.row );
	rowB = [NSIndexPath indexPathForRow: 0 inSection: 0];
	XCTAssertTrue( [rowA isBelowRowAtIndexPath: rowB], @"Row %d,%d should be below %d,%d", rowA.section, rowA.row, rowB.section, rowB.row );
}
//------------------------------------------------------------------------------

- (void) test_UITableViewReorder_reorderAutoScrollRate {
	UITableView *aTableView = [[UITableView alloc] initWithFrame: CGRectZero style: UITableViewStyleGrouped];
	
	XCTAssertEqual( [aTableView reorderAutoScrollRate], 0.0f, @"If the autoScrollRate has not been set, it should be zero" );
	aTableView.reorderAutoScrollRate = 0.5;
	XCTAssertEqual( [aTableView reorderAutoScrollRate], 0.5f, @"If the autoScrollRate is set to 0.5, it should be 0.5 not %g", aTableView.reorderAutoScrollRate );
	XCTAssertEqual( aTableView.reorderAutoScrollRate, 0.5f, @"If the autoScrollRate is set to 0.5, it should be 0.5 not %g", aTableView.reorderAutoScrollRate );
	aTableView.reorderAutoScrollRate = 1.0;
	XCTAssertEqual( [aTableView reorderAutoScrollRate], 1.0f, @"If the autoScrollRate is set to 1.0, it should be 1.0 not %g", aTableView.reorderAutoScrollRate  );
	XCTAssertEqual( aTableView.reorderAutoScrollRate, 1.0f, @"If the autoScrollRate is set to 1.0, it should be 1.0 not %g", aTableView.reorderAutoScrollRate  );
	aTableView.reorderAutoScrollRate = -0.5;
	XCTAssertEqual( [aTableView reorderAutoScrollRate], -0.5f, @"If the autoScrollRate is set to -0.5, it should be -0.5 not %g", aTableView.reorderAutoScrollRate  );
	XCTAssertEqual( aTableView.reorderAutoScrollRate, -0.5f, @"If the autoScrollRate is set to -0.5, it should be -0.5 not %g", aTableView.reorderAutoScrollRate  );
	aTableView.reorderAutoScrollRate = -1.0;
	XCTAssertEqual( [aTableView reorderAutoScrollRate], -1.0f, @"If the autoScrollRate is set to -1.0, it should be -1.0 not %g", aTableView.reorderAutoScrollRate  );
	XCTAssertEqual( aTableView.reorderAutoScrollRate, -1.0f, @"If the autoScrollRate is set to -1.0, it should be -1.0 not %g", aTableView.reorderAutoScrollRate  );
}

- (void) test_UITableViewReorder_reorderTouchOffset {
	UITableView *aTableView = [[UITableView alloc] initWithFrame: CGRectZero style: UITableViewStyleGrouped];
	
	XCTAssertTrue( CGPointEqualToPoint( aTableView.reorderTouchOffset, CGPointMake(0.0, 0.0) ), @"Not set should be 0,0" );
	aTableView.reorderTouchOffset = CGPointMake(   0.0,   0.0 );
	XCTAssertTrue( CGPointEqualToPoint( aTableView.reorderTouchOffset, CGPointMake(0.0, 0.0) ), @"0,0 should be 0.0" );
	aTableView.reorderTouchOffset = CGPointMake(  10.0,   0.0 );
	XCTAssertTrue( CGPointEqualToPoint( aTableView.reorderTouchOffset, CGPointMake(10.0, 0.0) ), @"10,0 should be 10,0" );
	aTableView.reorderTouchOffset = CGPointMake(   0.0,  10.0 );
	XCTAssertTrue( CGPointEqualToPoint( aTableView.reorderTouchOffset, CGPointMake(0.0, 10.0) ), @"0,10 should be 0,10" );
	aTableView.reorderTouchOffset = CGPointMake(  10.0,  10.0 );
	XCTAssertTrue( CGPointEqualToPoint( aTableView.reorderTouchOffset, CGPointMake(10.0, 10.0) ), @"10,10 should be 10,10" );
	aTableView.reorderTouchOffset = CGPointMake( -10.0,   0.0 );
	XCTAssertTrue( CGPointEqualToPoint( aTableView.reorderTouchOffset, CGPointMake(-10.0, 0.0) ), @"-10,0 should be -10,0" );
	aTableView.reorderTouchOffset = CGPointMake(   0.0, -10.0 );
	XCTAssertTrue( CGPointEqualToPoint( aTableView.reorderTouchOffset, CGPointMake(0.0, -10.0) ), @"0,-10 should be 0,-10" );
	aTableView.reorderTouchOffset = CGPointMake( -10.0, -10.0 );
	XCTAssertTrue( CGPointEqualToPoint( aTableView.reorderTouchOffset, CGPointMake(-10.0, -10.0) ), @"-10,-10 should be -10,-10" );
}

- (void) test_UITableViewReorder_toIndexPathForRowBeingMoved {
	UITableView *aTableView = [[UITableView alloc] initWithFrame: CGRectZero style: UITableViewStyleGrouped];
	NSIndexPath *indexPath;
	
	indexPath = aTableView.toIndexPathForRowBeingMoved;
	XCTAssertNil( indexPath, @"If not set, the toIndexPathForRowBeingMoved should be nil" );
	aTableView.toIndexPathForRowBeingMoved = [NSIndexPath indexPathForRow: 0 inSection: 0];
	indexPath = aTableView.toIndexPathForRowBeingMoved;
	XCTAssertNotNil( indexPath, @"The toIndexPathForRowBeingMoved should not be nil" );
	XCTAssertTrue( indexPath.row == 0 && indexPath.section == 0, @"The toIndexPathForRowBeingMoved should be 0,0" );
	aTableView.toIndexPathForRowBeingMoved = [NSIndexPath indexPathForRow: 0 inSection: 3];
	indexPath = aTableView.toIndexPathForRowBeingMoved;
	XCTAssertTrue( indexPath.row == 0 && indexPath.section == 3, @"The toIndexPathForRowBeingMoved should be 0,3" );
	aTableView.toIndexPathForRowBeingMoved = [NSIndexPath indexPathForRow: 3 inSection: 0];
	indexPath = aTableView.toIndexPathForRowBeingMoved;
	XCTAssertTrue( indexPath.row == 3 && indexPath.section == 0, @"The toIndexPathForRowBeingMoved should be 3,0" );
	aTableView.toIndexPathForRowBeingMoved = [NSIndexPath indexPathForRow: 2 inSection: 4];
	indexPath = aTableView.toIndexPathForRowBeingMoved;
	XCTAssertTrue( indexPath.row == 2 && indexPath.section == 4, @"The toIndexPathForRowBeingMoved should be 2,4" );
	aTableView.toIndexPathForRowBeingMoved = nil;
	indexPath = aTableView.toIndexPathForRowBeingMoved;
	XCTAssertNil( indexPath, @"If set to nil, the toIndexPathForRowBeingMoved should be nil" );
}

- (void) test_UITableViewReorder_fromIndexPathOfRowBeingMoved {
	UITableView *aTableView = [[UITableView alloc] initWithFrame: CGRectZero style: UITableViewStyleGrouped];
	NSIndexPath *indexPath;
	
	indexPath = aTableView.fromIndexPathOfRowBeingMoved;
	XCTAssertNil( indexPath, @"If not set, the fromIndexPathOfRowBeingMoved should be nil" );
	aTableView.fromIndexPathOfRowBeingMoved = [NSIndexPath indexPathForRow: 0 inSection: 0];
	indexPath = aTableView.fromIndexPathOfRowBeingMoved;
	XCTAssertNotNil( indexPath, @"The fromIndexPathOfRowBeingMoved should not be nil" );
	XCTAssertTrue( indexPath.row == 0 && indexPath.section == 0, @"The fromIndexPathOfRowBeingMoved should be 0,0" );
	aTableView.fromIndexPathOfRowBeingMoved = [NSIndexPath indexPathForRow: 0 inSection: 3];
	indexPath = aTableView.fromIndexPathOfRowBeingMoved;
	XCTAssertTrue( indexPath.row == 0 && indexPath.section == 3, @"The fromIndexPathOfRowBeingMoved should be 0,3" );
	aTableView.fromIndexPathOfRowBeingMoved = [NSIndexPath indexPathForRow: 3 inSection: 0];
	indexPath = aTableView.fromIndexPathOfRowBeingMoved;
	XCTAssertTrue( indexPath.row == 3 && indexPath.section == 0, @"The fromIndexPathOfRowBeingMoved should be 3,0" );
	aTableView.fromIndexPathOfRowBeingMoved = [NSIndexPath indexPathForRow: 2 inSection: 4];
	indexPath = aTableView.fromIndexPathOfRowBeingMoved;
	XCTAssertTrue( indexPath.row == 2 && indexPath.section == 4, @"The fromIndexPathOfRowBeingMoved should be 2,4" );
	aTableView.fromIndexPathOfRowBeingMoved = nil;
	indexPath = aTableView.fromIndexPathOfRowBeingMoved;
	XCTAssertNil( indexPath, @"If set to nil, the fromIndexPathOfRowBeingMoved should be nil" );
}

- (void) test_UITableViewReorder_snapShotOfCellBeingMoved {
	UITableView *aTableView = [[UITableView alloc] initWithFrame: CGRectZero style: UITableViewStyleGrouped];
	
	XCTAssertNil( aTableView.snapShotOfCellBeingMoved, @"If not set, the snapShotOfCellBeingMoved should be nil" );
	UIView *testView = [[UIView alloc] initWithFrame: CGRectZero];
	aTableView.snapShotOfCellBeingMoved = testView;
	XCTAssertNotNil( aTableView.snapShotOfCellBeingMoved, @"If set, the snapShotOfCellBeingMoved should not be nil" );
	XCTAssertEqualObjects( testView, aTableView.snapShotOfCellBeingMoved, @"They should be the same object" );
	aTableView.snapShotOfCellBeingMoved = nil;
	XCTAssertNil( aTableView.snapShotOfCellBeingMoved, @"If set to nil, the snapShotOfCellBeingMoved should be nil" );
}

- (void) test_UITableViewReorder_reorderAutoScrollTimer {
	UITableView *aTableView = [[UITableView alloc] initWithFrame: CGRectZero style: UITableViewStyleGrouped];
	
	XCTAssertNil( aTableView.reorderAutoScrollTimer, @"If not set, the reorderAutoScrollTimer should be nil" );
	aTableView.reorderAutoScrollTimer = [CADisplayLink displayLinkWithTarget: self selector: @selector(setUp)];
	XCTAssertNotNil( aTableView.reorderAutoScrollTimer, @"If set, the reorderAutoScrollTimer should not be nil" );
	aTableView.reorderAutoScrollTimer = nil;
	XCTAssertNil( aTableView.reorderAutoScrollTimer, @"If set to nil, the reorderAutoScrollTimer should be nil" );
}

- (void) test_UITableViewReorder_rowReorderGestureRecognizer {
	UITableView *aTableView = [[UITableView alloc] initWithFrame: CGRectZero style: UITableViewStyleGrouped];
	
	XCTAssertNil( aTableView.rowReorderGestureRecognizer, @"If not set, the rowReorderGestureRecognizer should be nil" );
	aTableView.rowReorderGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget: self action: @selector(setUp)];
	XCTAssertNotNil( aTableView.rowReorderGestureRecognizer, @"If set, the rowReorderGestureRecognizer should not be nil" );
	aTableView.rowReorderGestureRecognizer = nil;
	XCTAssertNil( aTableView.rowReorderGestureRecognizer, @"If set to nil, the rowReorderGestureRecognizer should be nil" );
}

- (void) test_UITableViewReorder_delegateForRowReorderGestureRecognizer {
	UITableView *aTableView = [[UITableView alloc] initWithFrame: CGRectZero style: UITableViewStyleGrouped];
	
	XCTAssertNil( aTableView.delegateForRowReorderGestureRecognizer, @"If not set, the delegateForRowMoveGestureRecognizer should be nil" );
	aTableView.delegateForRowReorderGestureRecognizer = (id <UIGestureRecognizerDelegate>) self;
	XCTAssertNotNil( aTableView.delegateForRowReorderGestureRecognizer, @"If set, the delegateForRowMoveGestureRecognizer should not be nil" );
	aTableView.delegateForRowReorderGestureRecognizer = nil;
	XCTAssertNil( aTableView.delegateForRowReorderGestureRecognizer, @"If set to nil, the delegateForRowMoveGestureRecognizer should be nil" );
}

//------------------------------------------------------------------------------

- (void) test_UITableViewReorder_shouldSubstitutePlaceHolderForCellBeingMovedAtIndexPath {
	UITableView *aTableView = [[UITableView alloc] initWithFrame: CGRectZero style: UITableViewStyleGrouped];
	NSIndexPath *pathA = [NSIndexPath indexPathForRow: 5 inSection: 3];
	NSIndexPath *pathB = [NSIndexPath indexPathForRow: 1 inSection: 2];
	NSIndexPath *pathC = [NSIndexPath indexPathForRow: 5 inSection: 3];

	XCTAssertFalse( [aTableView shouldSubstitutePlaceHolderForCellBeingMovedAtIndexPath: nil], @"A nil index path could never need substituting" );
	XCTAssertFalse( [aTableView shouldSubstitutePlaceHolderForCellBeingMovedAtIndexPath: pathC], @"A 0,0 index path could never need substituting without other things being set" );
	aTableView.fromIndexPathOfRowBeingMoved = pathA;
	XCTAssertFalse( [aTableView shouldSubstitutePlaceHolderForCellBeingMovedAtIndexPath: pathC], @"A 0,0 index path could never need substituting without other things being set" );
	XCTAssertFalse( [aTableView shouldSubstitutePlaceHolderForCellBeingMovedAtIndexPath: pathB], @"A 0,0 index path could never need substituting without other things being set" );
	aTableView.toIndexPathForRowBeingMoved = pathB;
	XCTAssertFalse( [aTableView shouldSubstitutePlaceHolderForCellBeingMovedAtIndexPath: pathC], @"A 0,0 index path could never need substituting without other things being set" );
	XCTAssertFalse( [aTableView shouldSubstitutePlaceHolderForCellBeingMovedAtIndexPath: pathB], @"A 0,0 index path could never need substituting without other things being set" );
	aTableView.snapShotOfCellBeingMoved = [[UIView alloc] initWithFrame: CGRectZero];
	XCTAssertFalse( [aTableView shouldSubstitutePlaceHolderForCellBeingMovedAtIndexPath: pathB], @"Should not substitute because 1,0 is not 0,0" );
	XCTAssertTrue( [aTableView shouldSubstitutePlaceHolderForCellBeingMovedAtIndexPath: pathC], @"Should substitute because everything is set and 0,0 is 0,0" );
}

- (void) test_UITableViewReorder_adjustedValueForReorderingOfRowCount {
	UITableView *aTableView = [[UITableView alloc] initWithFrame: CGRectZero style: UITableViewStyleGrouped];
	NSInteger rowCount;
	NSInteger adjustedRowCount;
	
	rowCount = 3;
	adjustedRowCount = [aTableView adjustedValueForReorderingOfRowCount: rowCount forSection: 0];
	XCTAssertTrue( adjustedRowCount == rowCount, @"There should be no change if the to and from indeces are not set" );
	aTableView.toIndexPathForRowBeingMoved = [NSIndexPath indexPathForRow: 0 inSection: 0];
	adjustedRowCount = [aTableView adjustedValueForReorderingOfRowCount: rowCount forSection: 0];
	XCTAssertTrue( adjustedRowCount == rowCount, @"There should be no change if the 'from' index is not set" );
	aTableView.toIndexPathForRowBeingMoved = nil;
	aTableView.fromIndexPathOfRowBeingMoved = [NSIndexPath indexPathForRow: 0 inSection: 0];
	adjustedRowCount = [aTableView adjustedValueForReorderingOfRowCount: rowCount forSection: 0];
	XCTAssertTrue( adjustedRowCount == rowCount, @"There should be no change if the 'to' index is not set" );
	aTableView.toIndexPathForRowBeingMoved = [NSIndexPath indexPathForRow: 0 inSection: 0];
	adjustedRowCount = [aTableView adjustedValueForReorderingOfRowCount: rowCount forSection: 0];
	XCTAssertTrue( adjustedRowCount == rowCount, @"There should be no change if the 'to' and 'from' are in the same section" );
	aTableView.toIndexPathForRowBeingMoved = [NSIndexPath indexPathForRow: 1 inSection: 4];
	adjustedRowCount = [aTableView adjustedValueForReorderingOfRowCount: rowCount forSection: 0];
	XCTAssertTrue( adjustedRowCount == rowCount - 1, @"The section is in the 'from' section so it should be rowCount-1" );
	adjustedRowCount = [aTableView adjustedValueForReorderingOfRowCount: rowCount forSection: 1];
	XCTAssertTrue( adjustedRowCount == rowCount, @"There should be no change if the section is not the 'to' or 'from'" );
	adjustedRowCount = [aTableView adjustedValueForReorderingOfRowCount: rowCount forSection: 4];
	XCTAssertTrue( adjustedRowCount == rowCount + 1, @"The section is in the 'to' section so it should be rowCount+1" );
	adjustedRowCount = [aTableView adjustedValueForReorderingOfRowCount: rowCount forSection: 5];
	XCTAssertTrue( adjustedRowCount == rowCount, @"There should be no change if the section is not the 'to' or 'from'" );
	
}

- (void) test_UITableViewReorder_dataSourceIndexPathFromVisibleIndexPath {
	UITableView *aTableView = [[UITableView alloc] initWithFrame: CGRectZero style: UITableViewStyleGrouped];

	// Set up our table structure for testing
	NSInteger sectionCount = 5;
	NSArray *rowsPerSection = @[ @3, @6, @3, @3, @2 ];

	// Neither 'to' nor 'from' are set...
	for( NSInteger section = 0; section < sectionCount; ++section ) {
		NSInteger rowCount = [rowsPerSection[section] integerValue];
		for( NSInteger row = 0; row < rowCount; ++row ) {
			NSIndexPath *dsPath = [aTableView dataSourceIndexPathFromVisibleIndexPath: [NSIndexPath indexPathForRow: row inSection: section]];
			XCTAssertTrue( dsPath.row == row && dsPath.section == section, @"Neither 'to' or 'from' are set, index path should not be changed" );
		}
	}

	// Only 'to' is set...
	aTableView.toIndexPathForRowBeingMoved = [NSIndexPath indexPathForRow: 1 inSection: 2];
	for( NSInteger section = 0; section < sectionCount; ++section ) {
		NSInteger rowCount = [rowsPerSection[section] integerValue];
		for( NSInteger row = 0; row < rowCount; ++row ) {
			NSIndexPath *dsPath = [aTableView dataSourceIndexPathFromVisibleIndexPath: [NSIndexPath indexPathForRow: row inSection: section]];
			XCTAssertTrue( dsPath.row == row && dsPath.section == section, @"'from' is not set, index path should not be changed" );
		}
	}

	// Only 'from' is set...
	aTableView.toIndexPathForRowBeingMoved = nil;
	aTableView.fromIndexPathOfRowBeingMoved = [NSIndexPath indexPathForRow: 1 inSection: 2];
	for( NSInteger section = 0; section < sectionCount; ++section ) {
		NSInteger rowCount = [rowsPerSection[section] integerValue];
		for( NSInteger row = 0; row < rowCount; ++row ) {
			NSIndexPath *dsPath = [aTableView dataSourceIndexPathFromVisibleIndexPath: [NSIndexPath indexPathForRow: row inSection: section]];
			XCTAssertTrue( dsPath.row == row && dsPath.section == section, @"'to' is not set, index path should not be changed" );
		}
	}

	// 'From' and 'to' are equal...
	aTableView.toIndexPathForRowBeingMoved = [NSIndexPath indexPathForRow: 1 inSection: 2];
	aTableView.fromIndexPathOfRowBeingMoved = [NSIndexPath indexPathForRow: 1 inSection: 2];
	for( NSInteger section = 0; section < sectionCount; ++section ) {
		NSInteger rowCount = [rowsPerSection[section] integerValue];
		for( NSInteger row = 0; row < rowCount; ++row ) {
			NSIndexPath *dsPath = [aTableView dataSourceIndexPathFromVisibleIndexPath: [NSIndexPath indexPathForRow: row inSection: section]];
			XCTAssertTrue( dsPath.row == row && dsPath.section == section, @"'to' and 'from' are equal, index path should not be changed" );
		}
	}

	// 'From' and 'to' in the same section...
	aTableView.fromIndexPathOfRowBeingMoved = [NSIndexPath indexPathForRow: 1 inSection: 1];
	aTableView.toIndexPathForRowBeingMoved = [NSIndexPath indexPathForRow: 3 inSection: 1];
	for( NSInteger section = 0; section < sectionCount; ++section ) {
		NSInteger rowCount = [rowsPerSection[section] integerValue];
		for( NSInteger row = 0; row < rowCount; ++row ) {
			NSIndexPath *dsPath = [aTableView dataSourceIndexPathFromVisibleIndexPath: [NSIndexPath indexPathForRow: row inSection: section]];
			if( section == aTableView.fromIndexPathOfRowBeingMoved.section ) {
				if( row < aTableView.fromIndexPathOfRowBeingMoved.row &&
				    row < aTableView.toIndexPathForRowBeingMoved.row ) {
					XCTAssertTrue( dsPath.row == row && dsPath.section == section, @"'to' and 'from' are in the same section, index path is before the 'from' and 'to'" );
				} else if( row > aTableView.fromIndexPathOfRowBeingMoved.row &&
					   row > aTableView.toIndexPathForRowBeingMoved.row ) {
					XCTAssertTrue( dsPath.row == row && dsPath.section == section, @"'to' and 'from' are in the same section, index path is after the 'from' and 'to'" );
				} else if( row > aTableView.fromIndexPathOfRowBeingMoved.row &&
					   row < aTableView.toIndexPathForRowBeingMoved.row ) {
					XCTAssertTrue( dsPath.row == row+1 && dsPath.section == section, @"'to' and 'from' are in the same section, index path is after the 'from' and before the 'to'" );
				} else if( row < aTableView.fromIndexPathOfRowBeingMoved.row &&
					   row > aTableView.toIndexPathForRowBeingMoved.row ) {
					XCTAssertTrue( dsPath.row == row-1 && dsPath.section == section, @"'to' and 'from' are in the same section, index path is after the 'from' and before the 'to'" );
				} else if( row == aTableView.fromIndexPathOfRowBeingMoved.row &&
					   row > aTableView.toIndexPathForRowBeingMoved.row ) {
					XCTAssertTrue( dsPath.row == row-1 && dsPath.section == section, @"'to' and 'from' are in the same section, index path is at the 'from' and before the 'to'" );
				} else if( row == aTableView.fromIndexPathOfRowBeingMoved.row &&
					   row < aTableView.toIndexPathForRowBeingMoved.row ) {
					XCTAssertTrue( dsPath.row == row+1 && dsPath.section == section, @"'to' and 'from' are in the same section, index path is at the 'from' and before the 'to'" );
				} else if( row == aTableView.toIndexPathForRowBeingMoved.row &&
					   row > aTableView.fromIndexPathOfRowBeingMoved.row ) {
					XCTAssertTrue( dsPath.row == aTableView.fromIndexPathOfRowBeingMoved.row && dsPath.section == aTableView.fromIndexPathOfRowBeingMoved.section, @"'to' and 'from' are in the same section, index path is at the 'to' and after the 'from'" );
				} else if( row == aTableView.toIndexPathForRowBeingMoved.row &&
					   row < aTableView.fromIndexPathOfRowBeingMoved.row ) {
					XCTAssertTrue( dsPath.row == aTableView.fromIndexPathOfRowBeingMoved.row && dsPath.section == aTableView.fromIndexPathOfRowBeingMoved.section, @"'to' and 'from' are in the same section, index path is at the 'to' and before the 'from'" );
				}
			} else {
				XCTAssertTrue( dsPath.row == row && dsPath.section == section, @"'to' and 'from' are in the same section, index path is in another section so should not be changed" );
			}
		}
	}

	// 'From' and 'to' in the same section...
	aTableView.fromIndexPathOfRowBeingMoved = [NSIndexPath indexPathForRow: 3 inSection: 1];
	aTableView.toIndexPathForRowBeingMoved = [NSIndexPath indexPathForRow: 1 inSection: 1];
	for( NSInteger section = 0; section < sectionCount; ++section ) {
		NSInteger rowCount = [rowsPerSection[section] integerValue];
		for( NSInteger row = 0; row < rowCount; ++row ) {
			NSIndexPath *dsPath = [aTableView dataSourceIndexPathFromVisibleIndexPath: [NSIndexPath indexPathForRow: row inSection: section]];
			if( section == aTableView.fromIndexPathOfRowBeingMoved.section ) {
				if( row < aTableView.fromIndexPathOfRowBeingMoved.row &&
				    row < aTableView.toIndexPathForRowBeingMoved.row ) {
					XCTAssertTrue( dsPath.row == row && dsPath.section == section, @"'to' and 'from' are in the same section, index path is before the 'from' and 'to'" );
				} else if( row > aTableView.fromIndexPathOfRowBeingMoved.row &&
					   row > aTableView.toIndexPathForRowBeingMoved.row ) {
					XCTAssertTrue( dsPath.row == row && dsPath.section == section, @"'to' and 'from' are in the same section, index path is after the 'from' and 'to'" );
				} else if( row > aTableView.fromIndexPathOfRowBeingMoved.row &&
					   row < aTableView.toIndexPathForRowBeingMoved.row ) {
					XCTAssertTrue( dsPath.row == row+1 && dsPath.section == section, @"'to' and 'from' are in the same section, index path is after the 'from' and before the 'to'" );
				} else if( row < aTableView.fromIndexPathOfRowBeingMoved.row &&
					   row > aTableView.toIndexPathForRowBeingMoved.row ) {
					XCTAssertTrue( dsPath.row == row-1 && dsPath.section == section, @"'to' and 'from' are in the same section, index path is after the 'from' and before the 'to'" );
				} else if( row == aTableView.fromIndexPathOfRowBeingMoved.row &&
					   row > aTableView.toIndexPathForRowBeingMoved.row ) {
					XCTAssertTrue( dsPath.row == row-1 && dsPath.section == section, @"'to' and 'from' are in the same section, index path is at the 'from' and before the 'to'" );
				} else if( row == aTableView.fromIndexPathOfRowBeingMoved.row &&
					   row < aTableView.toIndexPathForRowBeingMoved.row ) {
					XCTAssertTrue( dsPath.row == row+1 && dsPath.section == section, @"'to' and 'from' are in the same section, index path is at the 'from' and before the 'to'" );
				} else if( row == aTableView.toIndexPathForRowBeingMoved.row &&
					   row > aTableView.fromIndexPathOfRowBeingMoved.row ) {
					XCTAssertTrue( dsPath.row == aTableView.fromIndexPathOfRowBeingMoved.row && dsPath.section == aTableView.fromIndexPathOfRowBeingMoved.section, @"'to' and 'from' are in the same section, index path is at the 'to' and after the 'from'" );
				} else if( row == aTableView.toIndexPathForRowBeingMoved.row &&
					   row < aTableView.fromIndexPathOfRowBeingMoved.row ) {
					XCTAssertTrue( dsPath.row == aTableView.fromIndexPathOfRowBeingMoved.row && dsPath.section == aTableView.fromIndexPathOfRowBeingMoved.section, @"'to' and 'from' are in the same section, index path is at the 'to' and before the 'from'" );
				} else {
					XCTAssertTrue( NO, @"I don't think I should ever get here!" );
				}
			} else {
				XCTAssertTrue( dsPath.row == row && dsPath.section == section, @"'to' and 'from' are in the same section, index path is in another section so should not be changed" );
			}
		}
	}

	// 'From' and 'to' in different sections...
	aTableView.fromIndexPathOfRowBeingMoved = [NSIndexPath indexPathForRow: 1 inSection: 1];
	aTableView.toIndexPathForRowBeingMoved = [NSIndexPath indexPathForRow: 1 inSection: 3];
	for( NSInteger section = 0; section < sectionCount; ++section ) {
		NSInteger rowCount = [rowsPerSection[section] integerValue];
		NSInteger adjustedRowCount = [aTableView adjustedValueForReorderingOfRowCount: rowCount forSection: section];
		for( NSInteger row = 0; row < adjustedRowCount; ++row ) {
			NSIndexPath *dsPath = [aTableView dataSourceIndexPathFromVisibleIndexPath: [NSIndexPath indexPathForRow: row inSection: section]];
			if( section != aTableView.toIndexPathForRowBeingMoved.section &&
			    section != aTableView.fromIndexPathOfRowBeingMoved.section ) {
				XCTAssertTrue( dsPath.row == row && dsPath.section == section, @"'to' and 'from' are in different sections, index path is in a section that is not 'to' or 'from', so should not be changed" );
			} else if( section == aTableView.fromIndexPathOfRowBeingMoved.section ) {
				if( row < aTableView.fromIndexPathOfRowBeingMoved.row ) {
					XCTAssertTrue( dsPath.row == row && dsPath.section == section, @"'to' and 'from' are in different sections, index path is in the 'from' section before the from row so should not be changed" );
				} else {
					XCTAssertTrue( dsPath.row == row+1 && dsPath.section == section, @"'to' and 'from' are in different sections, index path is in the 'from' section at or after the from row so should be changed one higher" );
				}
			} else if( section == aTableView.toIndexPathForRowBeingMoved.section ) {
				if( row < aTableView.toIndexPathForRowBeingMoved.row ) {
					XCTAssertTrue( dsPath.row == row && dsPath.section == section, @"'to' and 'from' are in different sections, index path is in the 'to' section at or before the from row so should not be changed" );
				} else if( row == aTableView.toIndexPathForRowBeingMoved.row ) {
					XCTAssertTrue( dsPath.row == aTableView.fromIndexPathOfRowBeingMoved.row && dsPath.section == aTableView.fromIndexPathOfRowBeingMoved.section, @"'to' and 'from' are in different sections, index path is at the 'to' row in the 'to' section so should be changed to the from row and section" );
				} else {
					XCTAssertTrue( dsPath.row == row-1 && dsPath.section == section, @"'to' and 'from' are in different sections, index path is in the 'to' section after the to row so should be one lower" );
				}
			} else {
				XCTAssertTrue( aTableView.fromIndexPathOfRowBeingMoved.section == aTableView.toIndexPathForRowBeingMoved.section, @"If section is not not equal to both and not equal to either they must be equal to each other" );
			}
		}
	}

	// 'From' and 'to' in different sections...
	aTableView.fromIndexPathOfRowBeingMoved = [NSIndexPath indexPathForRow: 1 inSection: 3];
	aTableView.toIndexPathForRowBeingMoved = [NSIndexPath indexPathForRow: 1 inSection: 1];
	for( NSInteger section = 0; section < sectionCount; ++section ) {
		NSInteger rowCount = [rowsPerSection[section] integerValue];
		NSInteger adjustedRowCount = [aTableView adjustedValueForReorderingOfRowCount: rowCount forSection: section];
		for( NSInteger row = 0; row < adjustedRowCount; ++row ) {
			NSIndexPath *dsPath = [aTableView dataSourceIndexPathFromVisibleIndexPath: [NSIndexPath indexPathForRow: row inSection: section]];
			if( section != aTableView.toIndexPathForRowBeingMoved.section &&
			    section != aTableView.fromIndexPathOfRowBeingMoved.section ) {
				XCTAssertTrue( dsPath.row == row && dsPath.section == section, @"'to' and 'from' are in different sections, index path is in a section that is not 'to' or 'from', so should not be changed" );
			} else if( section == aTableView.fromIndexPathOfRowBeingMoved.section ) {
				if( row < aTableView.fromIndexPathOfRowBeingMoved.row ) {
					XCTAssertTrue( dsPath.row == row && dsPath.section == section, @"'to' and 'from' are in different sections, index path is in the 'from' section before the from row so should not be changed" );
				} else {
					XCTAssertTrue( dsPath.row == row+1 && dsPath.section == section, @"'to' and 'from' are in different sections, index path is in the 'from' section at or after the from row so should be changed one higher" );
				}
			} else if( section == aTableView.toIndexPathForRowBeingMoved.section ) {
				if( row < aTableView.toIndexPathForRowBeingMoved.row ) {
					XCTAssertTrue( dsPath.row == row && dsPath.section == section, @"'to' and 'from' are in different sections, index path is in the 'to' section at or before the from row so should not be changed" );
				} else if( row == aTableView.toIndexPathForRowBeingMoved.row ) {
					XCTAssertTrue( dsPath.row == aTableView.fromIndexPathOfRowBeingMoved.row && dsPath.section == aTableView.fromIndexPathOfRowBeingMoved.section, @"'to' and 'from' are in different sections, index path is at the 'to' row in the 'to' section so should be changed to the from row and section" );
				} else {
					XCTAssertTrue( dsPath.row == row-1 && dsPath.section == section, @"'to' and 'from' are in different sections, index path is in the 'to' section after the to row so should be one lower" );
				}
			} else {
				XCTAssertTrue( aTableView.fromIndexPathOfRowBeingMoved.section == aTableView.toIndexPathForRowBeingMoved.section, @"If section is not not equal to both and not equal to either they must be equal to each other" );
			}
		}
	}
}

@end
