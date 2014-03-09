//
//  UITableView+Reorder.m
//
//
//  Created by David W. Stockton on 3/3/14.
//  Copyright (c) 2014 Syntonicity, LLC. All rights reserved.
//

#import "UITableView+Reorder.h"
#import <objc/runtime.h>
#ifdef DEBUG
#define CONFIGURATION_VALIDATION
//#undef CONFIGURATION_VALIDATION
#endif

@interface NSIndexPath (Reorder)
- (BOOL) isBelowRowAtIndexPath: (NSIndexPath *) referencePath;
- (BOOL) isAboveRowAtIndexPath: (NSIndexPath *) referencePath;
@end

@interface delegateForReorderGesture : NSObject <UIGestureRecognizerDelegate>
@end

#define MAX_SCROLL_RATE	10		// Points/refresh (typically 1/60th second)

// Putting this here is just to help the Xcode autocomplete
@interface UITableView (ReorderPrivateMethods)
@property (nonatomic) CGPoint reorderTouchOffset;
@property (nonatomic) CGFloat reorderAutoScrollRate;
@property (nonatomic, strong) NSIndexPath *fromIndexPathOfRowBeingMoved;
@property (nonatomic, strong) NSIndexPath *toIndexPathForRowBeingMoved;
@property (nonatomic, strong) UIView *snapShotOfCellBeingMoved;
@property (nonatomic, strong) CADisplayLink *reorderAutoScrollTimer;
@property (nonatomic, strong) UILongPressGestureRecognizer *rowReorderGestureRecognizer;
@property (nonatomic, strong) id <UIGestureRecognizerDelegate> delegateForRowReorderGestureRecognizer;
@end

@implementation UITableView (Reorder)

static void *allowsLongPressToReorderKey = &allowsLongPressToReorderKey;
- (void) setAllowsLongPressToReorder: (BOOL) allowsLongPressToReorder {
#ifdef CONFIGURATION_VALIDATION
	if( allowsLongPressToReorder ) [self verifyConfiguration];
#endif
	if( allowsLongPressToReorder != self.allowsLongPressToReorder ) {
		objc_setAssociatedObject( self, allowsLongPressToReorderKey, [NSNumber numberWithBool: allowsLongPressToReorder], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		if( !self.allowsLongPressToReorderDuringEditing ) {
			if( allowsLongPressToReorder ) {
				self.rowReorderGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget: self action: @selector(rowReorderGesture:)];
				self.delegateForRowReorderGestureRecognizer = [[delegateForReorderGesture alloc] init];
				self.rowReorderGestureRecognizer.delegate = self.delegateForRowReorderGestureRecognizer;
				NSLog( @"Set gesture recognizer and its delegate" );
			} else {
				self.delegateForRowReorderGestureRecognizer = nil;
				self.rowReorderGestureRecognizer = nil;
				NSLog( @"Cleared gesture recognizer and its delegate" );
			}
		}
	}
}
- (BOOL) allowsLongPressToReorder {
	BOOL allows = [objc_getAssociatedObject( self, allowsLongPressToReorderKey ) boolValue];
	return allows;
}
static void *allowsLongPressToReorderDuringEditingKey = &allowsLongPressToReorderDuringEditingKey;
- (void) setAllowsLongPressToReorderDuringEditing: (BOOL) allowsLongPressToReorderDuringEditing {
#ifdef CONFIGURATION_VALIDATION
	if( allowsLongPressToReorderDuringEditing ) [self verifyConfiguration];
#endif
	if( allowsLongPressToReorderDuringEditing != self.allowsLongPressToReorderDuringEditing ) {
		objc_setAssociatedObject( self, allowsLongPressToReorderDuringEditingKey, [NSNumber numberWithBool: allowsLongPressToReorderDuringEditing], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		if( !self.allowsLongPressToReorder ) {
			if( allowsLongPressToReorderDuringEditing ) {
				self.rowReorderGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget: self action: @selector(rowReorderGesture:)];
				self.delegateForRowReorderGestureRecognizer = [[delegateForReorderGesture alloc] init];
				self.rowReorderGestureRecognizer.delegate = self.delegateForRowReorderGestureRecognizer;
				NSLog( @"Set gesture recognizer and its delegate" );
			} else {
				self.delegateForRowReorderGestureRecognizer = nil;
				self.rowReorderGestureRecognizer = nil;
				NSLog( @"Cleared gesture recognizer and its delegate" );
			}
		}
	}
}
- (BOOL) allowsLongPressToReorderDuringEditing {
	BOOL allows = [objc_getAssociatedObject( self, allowsLongPressToReorderDuringEditingKey ) boolValue];
	return allows;
}

- (void) rowReorderGesture: (UIGestureRecognizer *) gesture {
	UIView	*viewForGesture = gesture.view;
	if( ![viewForGesture isKindOfClass: [UITableView class]] ) {
		NSLog( @"***** The rowReorderGesture is not attached to a UITableView" );
	} else if( viewForGesture != self ) {
		NSLog( @"***** The rowReorderGesture is not attached to self" );
	}
	CGPoint currentLocation = [gesture locationInView: self];
	//NSIndexPath *indexPathOfLocation = [self indexPathForRowAtPoint: currentLocation];
	// Note that touching just below a section in the section header or
	// footer ends up being identified as row 0 in section 0! Maybe I should
	// trap 0/0's and double check to see if this is correct?
	switch( gesture.state ) {
		case UIGestureRecognizerStatePossible:
			NSLog( @"Recognized a long-press on a tableView - State Possible" );
			break;
		case UIGestureRecognizerStateBegan:
			//NSLog( @"Recognized a long-hold on a tableView" );
			//NSLog( @"- State Began at row %d in section %d", indexPathOfLocation.row, indexPathOfLocation.section );
			[self prepareForMoveOfRowAtPoint: currentLocation];
			break;
		case UIGestureRecognizerStateChanged:
			//NSLog( @"Recognized a long-hold on a tableView" );
			//NSLog( @"- State Changed" );
			[self movingRowIsAtPoint: currentLocation];
			break;
		case UIGestureRecognizerStateEnded:
			//NSLog( @"Recognized a long-hold on a tableView" );
			//NSLog( @"- State Ended/Recognized at row %d in section %d", indexPathOfLocation.row, indexPathOfLocation.section );
			[self finishMovingRowToPoint: currentLocation];
			break;
		case UIGestureRecognizerStateCancelled:
			//NSLog( @"Recognized a long-hold on a tableView" );
			//NSLog( @"- State Cancelled" );
			[self cancelMovingRowAtPoint: currentLocation];
			break;
		case UIGestureRecognizerStateFailed:
			NSLog( @"Recognized a long-press on a tableView - State Failed" );
			break;
	}
}
- (void) prepareForMoveOfRowAtPoint: (CGPoint) point {
	NSIndexPath *indexPathOfPoint = [self indexPathForRowAtPoint: point];
	// See if the datasource says we cannot move the selected row
	if( indexPathOfPoint &&
	   [self.dataSource respondsToSelector: @selector(tableView:moveRowAtIndexPath:toIndexPath:)] &&
	   (![self.dataSource respondsToSelector: @selector(tableView:canEditRowAtIndexPath:)] ||
	    [self.dataSource tableView: self canEditRowAtIndexPath: indexPathOfPoint]) &&
	   (![self.dataSource respondsToSelector: @selector(tableView:canMoveRowAtIndexPath:)] ||
	    [self.dataSource tableView: self canMoveRowAtIndexPath: indexPathOfPoint]) ) {
		   // Tell the delegate that we are about to make a move, if it wants to know
		   if( [self.delegate respondsToSelector: @selector(tableView:willMoveRowAtIndexPath:)] ) {
			   [(id) self.delegate tableView: self willMoveRowAtIndexPath: indexPathOfPoint];
		   }
		   // Get the view to drag up and down the screen
		   self.snapShotOfCellBeingMoved = [self snapShotViewOfCellAtIndexPath: indexPathOfPoint];
		   // Add the floating apparition of the cell being moved to the tableview
#ifdef ANIMATE_SNAPSHOT_SUBVIEW
		   self.snapShotOfCellBeingMoved.alpha = 0.0;
		   [self addSubview: self.snapShotOfCellBeingMoved];
		   [UIView animateWithDuration: .2 animations:^{
			   self.snapShotOfCellBeingMoved.alpha = 1.0;
		   }];
#else
		   [self addSubview: self.snapShotOfCellBeingMoved];
#endif
		   self.reorderTouchOffset = CGPointMake( self.snapShotOfCellBeingMoved.center.x - point.x, self.snapShotOfCellBeingMoved.center.y - point.y);
		   // Record the location of the cell to be moved
		   self.fromIndexPathOfRowBeingMoved = indexPathOfPoint;
		   self.toIndexPathForRowBeingMoved = indexPathOfPoint;
		   // Now reload the cell so the placeholder is loaded into the table
		   [self reloadRowsAtIndexPaths: @[indexPathOfPoint] withRowAnimation: UITableViewRowAnimationFade];
	   } else {
		   NSLog( @"- - But the table view data source says this row cannot be moved" );
	   }
}

- (void) movingRowIsAtPoint: (CGPoint) point  {
	// Based on the point from the gesture, calculate where the center of
	// the snap shot view being dragged should be. Clamp it so its center
	// can go the full range of the visible tableview, but not beyond.
	CGFloat newCenterY = point.y + self.reorderTouchOffset.y;
	if( newCenterY < self.contentOffset.y + self.contentInset.top )
		newCenterY = self.contentOffset.y + self.contentInset.top;
	if( newCenterY > CGRectGetMaxY(self.bounds) - self.contentInset.bottom )
		newCenterY = CGRectGetMaxY(self.bounds) - self.contentInset.bottom;
	self.snapShotOfCellBeingMoved.center = CGPointMake( self.snapShotOfCellBeingMoved.center.x, newCenterY );
	
	// No need to check about scrolling if the content size is not
	// larger than the tableView size.
	// OK, is this test going to help or hurt performance? If there will not
	// be any scrolling then there is nothing to slow down. If there will be
	// scrolling I've put one more test and calculation into it...
	if( self.contentSize.height + self.contentInset.top + self.contentInset.bottom > CGRectGetHeight(self.bounds) ) {
		NSLog( @"The content size (plus insets) is larger than the tableView height so it can scroll" );
	}
        CGRect rect = self.bounds;
        // adjust rect for content inset as we will use it below for calculating scroll zones
        rect.size.height -= self.contentInset.top;
	
	// tell us if we should scroll and which direction
        //CGFloat scrollZoneHeight = rect.size.height / 6;	// Divide the screen into zones
	CGFloat scrollZoneHeight = 6;
        CGFloat topScrollBeginning = self.contentOffset.y + self.contentInset.top + scrollZoneHeight;
	// Note that tableView.contentOffset.y + tableView.contentInset.top + rect.size.height seems to be the same as CGRectGetMaxY(tableView.bounds)
        CGFloat bottomScrollBeginning = self.contentOffset.y + self.contentInset.top - self.contentInset.bottom + rect.size.height - scrollZoneHeight;
	//if( (tableView.contentOffset.y + tableView.contentInset.top + rect.size.height) != CGRectGetMaxY(tableView.bounds) ) {
	//	NSLog( @"The contentOffset.y+contentInset.top+tableView.bounds.height = %g and the maxY from tableView.bounds is %g", tableView.contentOffset.y + tableView.contentInset.top + rect.size.height, CGRectGetMaxY(tableView.bounds) );
	//} else {
	//	NSLog( @"The contentOffset.y+contentInset.top+tableView.bounds.height and the maxY from tableView.bounds are the same" );
	//}
	//NSLog( @"=== The boundaries of the scroll regions are at %g and %g", topScrollBeginning, bottomScrollBeginning );
	NSLog( @"The tableView.contentInsets %g top, %g bottom, %g left, %g right", self.contentInset.top, self.contentInset.bottom, self.contentInset.left, self.contentInset.right );
	NSLog( @"The tableView.contentOffset %g in x, %g in y", self.contentOffset.x, self.contentOffset.y );
	NSLog( @"The tableView.bounds are %@", NSStringFromCGRect(self.bounds) );
	NSLog( @"The tableView.contentSize is %@", NSStringFromCGSize(self.contentSize) );
        // We're in the bottom scroll zone
        if( CGRectGetMaxY(self.snapShotOfCellBeingMoved.frame) >= bottomScrollBeginning &&
	   CGRectGetMaxY(self.bounds) < self.contentSize.height - self.contentInset.bottom ) {
		self.reorderAutoScrollRate = (CGRectGetMaxY(self.snapShotOfCellBeingMoved.frame) - bottomScrollBeginning) / (scrollZoneHeight + self.snapShotOfCellBeingMoved.bounds.size.height / 2);
		// We're in the top scroll zone and the content offset is greater than zero (can be reduced)
        } else if( CGRectGetMinY(self.snapShotOfCellBeingMoved.frame) <= topScrollBeginning &&
		  self.contentOffset.y > -self.contentInset.top ) {
		self.reorderAutoScrollRate = (CGRectGetMinY(self.snapShotOfCellBeingMoved.frame) - topScrollBeginning) / (scrollZoneHeight + self.snapShotOfCellBeingMoved.bounds.size.height / 2);
        } else {
		self.reorderAutoScrollRate = 0.0;
		// Stop the autoscroll timer if needed
 		if( self.reorderAutoScrollTimer ) {
			[self.reorderAutoScrollTimer invalidate];
			self.reorderAutoScrollTimer = nil;
		}
		[self movePlaceHolderRowIfNeeded];
	}
	// Start the autoscroll timer if needed
	if( self.reorderAutoScrollRate != 0.0 && !self.reorderAutoScrollTimer ) {
		self.reorderAutoScrollTimer = [CADisplayLink displayLinkWithTarget: self selector: @selector(reorderAutoScrollTimerFired:)];
		[self.reorderAutoScrollTimer addToRunLoop: [NSRunLoop mainRunLoop] forMode: NSDefaultRunLoopMode];
	}
}

- (void) movePlaceHolderRowIfNeeded {
	// Get the index path of the row the user that dragged to
	// ---- This is flawed. When moving rows of differing heights the row
	//      the point is in changes every time the row order changes. I need
	//      better logic here, maybe some sort of rectangle intersecting.
	// ---- OK, reworked this to:
	//	1. See if the new location of the snapShot is above or below the
	//	   'toLocation' (the snapShot's assigned location).
	//	2. If above:
	//		See if the top edge is above the center of the cell above
	//	2. If below:
	//		See if the bottom edge is below the center of the cell below
#if 1
	CGRect whereWeWere = [self rectForRowAtIndexPath: self.toIndexPathForRowBeingMoved];
	CGRect whereWeAre = self.snapShotOfCellBeingMoved.frame;
	CGFloat centerX = self.snapShotOfCellBeingMoved.center.x;
	// If where we are is less than where we were, we are moving the row up
	if( CGRectGetMinY(whereWeAre) < CGRectGetMinY(whereWeWere) ) {
		NSIndexPath *rowUnderTopEdge = [self indexPathForRowAtPoint: CGPointMake( centerX,  CGRectGetMinY(whereWeAre))];
		// OK, this says there is a row under the top edge but sometimes
		// it lies and is really in a gap...
		if( rowUnderTopEdge ) {
			NSLog( @"++++ The top edge is in row %d of section %d", rowUnderTopEdge.row, rowUnderTopEdge.section );
			CGRect rectForRowUnderTopEdge = [self rectForRowAtIndexPath: rowUnderTopEdge];
			NSLog( @"     Top edge is at %g, row it is over goes from %g to %g", CGRectGetMinY(whereWeAre), CGRectGetMinY(rectForRowUnderTopEdge), CGRectGetMaxY(rectForRowUnderTopEdge) );
			if( CGRectGetMinY(whereWeAre) > CGRectGetMaxY(rectForRowUnderTopEdge) ) {
				NSLog( @"     - We are actually still below that row" );
				// Maybe we are into another row and not in a gap?
				rowUnderTopEdge = nil;
			}
			if( CGRectGetMinY(whereWeAre) < CGRectGetMinY(rectForRowUnderTopEdge) ) {
				NSLog( @"     - We are actually aleady above that row" );
				// Maybe we are into another row and not in a gap?
				rowUnderTopEdge = nil;
			}
		}
		if( rowUnderTopEdge ) {
			// Adjust the destination based on the delegate method
			if( [self.delegate respondsToSelector: @selector(tableView:targetIndexPathForMoveFromRowAtIndexPath:toProposedIndexPath:)] ) {
				rowUnderTopEdge = [self.delegate tableView: self targetIndexPathForMoveFromRowAtIndexPath: self.fromIndexPathOfRowBeingMoved toProposedIndexPath: rowUnderTopEdge];
			}
			if( !rowUnderTopEdge ) NSLog( @"**** going to try to move to nil index path!!" );
			// Make sure the destination row is different from the source
			if( [self.toIndexPathForRowBeingMoved compare: rowUnderTopEdge] != NSOrderedSame ) {
				CGRect whereWeMightGo = [self rectForRowAtIndexPath: rowUnderTopEdge];
				if( CGRectGetMinY(whereWeAre) <= CGRectGetMidY(whereWeMightGo) ) {
					[self movePlaceHolderRowFromIndexPath: self.toIndexPathForRowBeingMoved toIndexPath: rowUnderTopEdge];
				}
			}
		} else {
			// We may be above the first row of the first section...
			CGRect firstHeaderRect = [self rectForHeaderInSection: 0];
			if( CGRectGetMinY(whereWeAre) <= CGRectGetMaxY(firstHeaderRect) ) {
				NSLog( @"++++ The top edge is in first section's header" );
				rowUnderTopEdge = [NSIndexPath indexPathForRow: 0 inSection: 0];
				// Adjust the destination based on the delegate method
				if( [self.delegate respondsToSelector: @selector(tableView:targetIndexPathForMoveFromRowAtIndexPath:toProposedIndexPath:)] ) {
					rowUnderTopEdge = [self.delegate tableView: self targetIndexPathForMoveFromRowAtIndexPath: self.fromIndexPathOfRowBeingMoved toProposedIndexPath: rowUnderTopEdge];
				}
				if( rowUnderTopEdge.length == 0 ) NSLog( @"**** going to try to move to nil index path!!" );
				// Make sure the destination row is different from the source
				if( [self.toIndexPathForRowBeingMoved compare: rowUnderTopEdge] != NSOrderedSame ) {
					[self movePlaceHolderRowFromIndexPath: self.toIndexPathForRowBeingMoved toIndexPath: rowUnderTopEdge];
				}
			} else {
				// We are encroaching on a gap between sections...
				// We need to figure out what gap we are in. How do I do this efficiently?
				NSArray *visibleRows = [self indexPathsForVisibleRows];
				// This presumes the index paths for the visible rows are returned in order...
				NSInteger topSection = [[visibleRows firstObject] section];
				NSInteger bottomSection = [[visibleRows lastObject] section];
				NSInteger destinationSection = -1;
				CGFloat midGap = -1.0;
				NSLog( @"++++ The sections on the screen go from %d to %d", topSection, bottomSection );
				for( NSInteger section = topSection; section <= bottomSection; ++section ) {
					CGRect sectionHeaderRect = [self rectForHeaderInSection: section];
					CGRect sectionFooterRect = [self rectForFooterInSection: section];
					NSLog( @"     Section %d header: %@, footer: %@", section, NSStringFromCGRect(sectionHeaderRect), NSStringFromCGRect(sectionFooterRect) );
					if( CGRectGetMinY(whereWeAre)  > CGRectGetMinY(sectionHeaderRect) &&
					    CGRectGetMinY(whereWeAre) <= CGRectGetMaxY(sectionHeaderRect) ) {
						NSLog( @"     - We are in the header of section %d (%g <- %g -> %g)", section, CGRectGetMinY(sectionHeaderRect), CGRectGetMinY(whereWeAre), CGRectGetMaxY(sectionHeaderRect) );
						// What if we are at the first section?
						// -- If it is the header of the first section
						//    then our target row should be the first row of the first section.
						if( section > 0 ) {
							sectionFooterRect = [self rectForFooterInSection: section - 1];
							midGap = (CGRectGetMinY(sectionFooterRect) + CGRectGetMaxY(sectionHeaderRect)) / 2.0;
							destinationSection = section - 1;
						}
						break;
					} else if( CGRectGetMinY(whereWeAre)  > CGRectGetMinY(sectionFooterRect) &&
						   CGRectGetMinY(whereWeAre) <= CGRectGetMaxY(sectionFooterRect) ) {
						NSLog( @"     - We are in the footer of section %d (%g <- %g -> %g)", section, CGRectGetMinY(sectionFooterRect), CGRectGetMinY(whereWeAre), CGRectGetMaxY(sectionFooterRect) );
						// What if we are at the last section?
						// -- If it is the footer of the last section
						//    then our target row should be the last row of the last section.
						if( section < [self numberOfSections] - 1 ) {
							sectionHeaderRect = [self rectForHeaderInSection: section + 1];
							midGap = (CGRectGetMinY(sectionFooterRect) + CGRectGetMaxY(sectionHeaderRect)) / 2.0;
							destinationSection = section;
						} else {
							midGap = CGRectGetMinY(sectionFooterRect);
							destinationSection = [self numberOfSections] - 1;
						}
						break;
					}
				}
				if( CGRectGetMinY(whereWeAre) <= midGap && destinationSection >= 0 && destinationSection < [self numberOfSections] ) {
					NSLog( @"---- Do the move to the last row of section %d!", destinationSection );
					NSInteger destinationRow = [self numberOfRowsInSection: destinationSection];
					rowUnderTopEdge = [NSIndexPath indexPathForRow: destinationRow inSection: destinationSection];
					// Adjust the destination based on the delegate method
					if( [self.delegate respondsToSelector: @selector(tableView:targetIndexPathForMoveFromRowAtIndexPath:toProposedIndexPath:)] ) {
						rowUnderTopEdge = [self.delegate tableView: self targetIndexPathForMoveFromRowAtIndexPath: self.fromIndexPathOfRowBeingMoved toProposedIndexPath: rowUnderTopEdge];
					}
					if( rowUnderTopEdge.length == 0 ) NSLog( @"**** going to try to move to nil index path!!" );
					// Make sure the destination row is different from the source row
					if( [self.toIndexPathForRowBeingMoved compare: rowUnderTopEdge] != NSOrderedSame ) {
						[self movePlaceHolderRowFromIndexPath: self.toIndexPathForRowBeingMoved toIndexPath: rowUnderTopEdge];
					}
				} else {
					NSLog( @"---- No move yet, not to the middle of the gap" );
				}
			}
		}
	// If where we are is greater than where we were, we are moving the row down
	} else if( CGRectGetMaxY(whereWeAre) > CGRectGetMaxY(whereWeWere) ) {
		NSIndexPath *rowUnderBottomEdge = [self indexPathForRowAtPoint: CGPointMake( centerX,  CGRectGetMaxY(whereWeAre))];
		// OK, this says there is a row under the bottom edge but sometimes
		// it lies and is really in a gap...
		if( rowUnderBottomEdge ) {
			NSLog( @"++++ The bottom edge is in row %d of section %d", rowUnderBottomEdge.row, rowUnderBottomEdge.section );
			CGRect rectForRowUnderBottomEdge = [self rectForRowAtIndexPath: rowUnderBottomEdge];
			NSLog( @"     Bottom edge is at %g, row it is over goes from %g to %g", CGRectGetMaxY(whereWeAre), CGRectGetMinY(rectForRowUnderBottomEdge), CGRectGetMaxY(rectForRowUnderBottomEdge) );
			if( CGRectGetMaxY(whereWeAre) > CGRectGetMaxY(rectForRowUnderBottomEdge) ) {
				NSLog( @"     - We are actually already below that row" );
				// Maybe we are into another row and not in a gap?
				rowUnderBottomEdge = nil;
			}
			if( CGRectGetMaxY(whereWeAre) < CGRectGetMinY(rectForRowUnderBottomEdge) ) {
				NSLog( @"     - We are actually still above that row" );
				// Maybe we are into another row and not in a gap?
				rowUnderBottomEdge = nil;
			}
		}
		if( rowUnderBottomEdge.length > 0 ) {
			// We are encoaching on a row...
			// Adjust the destination based on the delegate method
			if( [self.delegate respondsToSelector: @selector(tableView:targetIndexPathForMoveFromRowAtIndexPath:toProposedIndexPath:)] ) {
				rowUnderBottomEdge = [self.delegate tableView: self targetIndexPathForMoveFromRowAtIndexPath: self.fromIndexPathOfRowBeingMoved toProposedIndexPath: rowUnderBottomEdge];
			}
			if( rowUnderBottomEdge.length == 0 ) NSLog( @"**** going to try to move to nil index path!!" );
			// Make sure the destination row is different from the source
			if( [self.toIndexPathForRowBeingMoved compare: rowUnderBottomEdge] != NSOrderedSame ) {
				CGRect whereWeMightGo = [self rectForRowAtIndexPath: rowUnderBottomEdge];
				if( CGRectGetMaxY(whereWeAre) >= CGRectGetMidY(whereWeMightGo) ) {
					[self movePlaceHolderRowFromIndexPath: self.toIndexPathForRowBeingMoved toIndexPath: rowUnderBottomEdge];
				}
			}
		} else {
			// We may be below the last row of the last section...
			NSInteger lastSection = [self numberOfSections] - 1;
			CGRect lastFooterRect = [self rectForFooterInSection: lastSection];
			if( CGRectGetMaxY(whereWeAre) >= CGRectGetMinY(lastFooterRect) ) {
				NSLog( @"++++ The bottom edge is in last section's footer" );
				rowUnderBottomEdge = [NSIndexPath indexPathForRow: [self numberOfRowsInSection: lastSection] - 1 inSection: lastSection];
				// Adjust the destination based on the delegate method
				if( [self.delegate respondsToSelector: @selector(tableView:targetIndexPathForMoveFromRowAtIndexPath:toProposedIndexPath:)] ) {
					rowUnderBottomEdge = [self.delegate tableView: self targetIndexPathForMoveFromRowAtIndexPath: self.fromIndexPathOfRowBeingMoved toProposedIndexPath: rowUnderBottomEdge];
				}
				if( rowUnderBottomEdge.length == 0 ) NSLog( @"**** going to try to move to nil index path!!" );
				// Make sure the destination row is different from the source
				if( [self.toIndexPathForRowBeingMoved compare: rowUnderBottomEdge] != NSOrderedSame ) {
					[self movePlaceHolderRowFromIndexPath: self.toIndexPathForRowBeingMoved toIndexPath: rowUnderBottomEdge];
				}
			} else {
				// We may be encroaching on a gap between sections...
				// We need to figure out what gap we are in. How do I do this efficiently?
				NSArray *visibleRows = [self indexPathsForVisibleRows];
				// This presumes the index paths for the visible rows are returned in order...
				NSInteger topSection = [[visibleRows firstObject] section];
				NSInteger bottomSection = [[visibleRows lastObject] section];
				NSInteger destinationSection = -1;
				CGFloat midGap = -1.0;
				NSLog( @"++++ The sections on the screen go from %d to %d", topSection, bottomSection );
				for( NSInteger section = topSection; section <= bottomSection; ++section ) {
					CGRect sectionHeaderRect = [self rectForHeaderInSection: section];
					CGRect sectionFooterRect = [self rectForFooterInSection: section];
					NSLog( @"     Section %d header: %@, footer: %@", section, NSStringFromCGRect(sectionHeaderRect), NSStringFromCGRect(sectionFooterRect) );
					// See if we are in the header of this section...
					if( CGRectGetMaxY(whereWeAre)  > CGRectGetMinY(sectionHeaderRect) &&
					    CGRectGetMaxY(whereWeAre) <= CGRectGetMaxY(sectionHeaderRect) ) {
						NSLog( @"     - We are in the header of section %d (%g <- %g -> %g)", section, CGRectGetMinY(sectionHeaderRect), CGRectGetMinY(whereWeAre), CGRectGetMaxY(sectionHeaderRect) );
						// What if we are at the first section?
						// -- If it is the header of the first section
						//    then our target row should be the first row of the first section.
						if( section > 0 ) {
							sectionFooterRect = [self rectForFooterInSection: section - 1];
							midGap = (CGRectGetMinY(sectionFooterRect) + CGRectGetMaxY(sectionHeaderRect)) / 2.0;
							destinationSection = section;
						} else {
							midGap = CGRectGetMaxY(sectionHeaderRect);
							destinationSection = 0;
						}
						break;
					// See if we are in the footer of this section...
					} else if( CGRectGetMaxY(whereWeAre)  > CGRectGetMinY(sectionFooterRect) &&
						   CGRectGetMaxY(whereWeAre) <= CGRectGetMaxY(sectionFooterRect) ) {
						NSLog( @"     - We are in the footer of section %d (%g <- %g -> %g)", section, CGRectGetMinY(sectionFooterRect), CGRectGetMinY(whereWeAre), CGRectGetMaxY(sectionFooterRect) );
						// What if we are at the last section?
						// -- If it is the footer of the last section
						//    then our target row should be the last row of the last section.
						if( section < [self numberOfSections] - 1 ) {
							sectionHeaderRect = [self rectForHeaderInSection: section + 1];
							midGap = (CGRectGetMinY(sectionFooterRect) + CGRectGetMaxY(sectionHeaderRect)) / 2.0;
							destinationSection = section + 1;
						}
						break;
					}
				}
				if( CGRectGetMaxY(whereWeAre) >= midGap && destinationSection >= 0 && destinationSection < [self numberOfSections]) {
					NSLog( @"---- Do the move to the first row of section %d!", destinationSection );
					rowUnderBottomEdge = [NSIndexPath indexPathForRow: 0 inSection: destinationSection];
					// Adjust the destination based on the delegate method
					if( [self.delegate respondsToSelector: @selector(tableView:targetIndexPathForMoveFromRowAtIndexPath:toProposedIndexPath:)] ) {
						rowUnderBottomEdge = [self.delegate tableView: self targetIndexPathForMoveFromRowAtIndexPath: self.fromIndexPathOfRowBeingMoved toProposedIndexPath: rowUnderBottomEdge];
					}
					// Make sure the destination row is different from the source row
					if( [self.toIndexPathForRowBeingMoved compare: rowUnderBottomEdge] != NSOrderedSame ) {
						[self movePlaceHolderRowFromIndexPath: self.toIndexPathForRowBeingMoved toIndexPath: rowUnderBottomEdge];
					}
				} else {
					NSLog( @"---- No move yet, not to the middle of the gap" );
				}
			}
		}
	}
#elif 1
	CGFloat topOfSnapShot = CGRectGetMinY(self.snapShotOfCellBeingMoved.frame);
	CGFloat topOfToLocation = CGRectGetMinY([self rectForRowAtIndexPath: self.toIndexPathForRowBeingMoved]);
	CGFloat bottomOfHeader = CGRectGetMaxY([self rectForHeaderInSection: self.toIndexPathForRowBeingMoved.section]);
	NSLog( @"----------------------------------------" );
	NSLog( @"- The snap shot cell's top edge is at %g and bottom edge is at %g", topOfSnapShot, CGRectGetMaxY(self.snapShotOfCellBeingMoved.frame) );
	NSLog( @"- The top of the blank row is at %g and the bottom edge is at %g", topOfToLocation, CGRectGetMaxY([self rectForRowAtIndexPath: self.toIndexPathForRowBeingMoved]) );
	NSLog( @"- The bottom of the header is at %g", bottomOfHeader );
	NSIndexPath *rowUnderTopEdge = [self indexPathForRowAtPoint: CGPointMake( self.snapShotOfCellBeingMoved.center.x,  topOfSnapShot)];
	NSIndexPath *rowUnderBottomEdge = [self indexPathForRowAtPoint: CGPointMake( self.snapShotOfCellBeingMoved.center.x,  CGRectGetMaxY(self.snapShotOfCellBeingMoved.frame))];
	if( rowUnderTopEdge ) {
		NSLog( @"- The row at the top edge is %d in section %d", rowUnderTopEdge.row, rowUnderTopEdge.section );
	} else {
		NSLog( @"- The row at the top edge is nil" );
	}
	if( rowUnderBottomEdge ) {
		NSLog( @"- The row at the bottom edge is %d in section %d", rowUnderBottomEdge.row, rowUnderBottomEdge.section );
	} else {
		NSLog( @"- The row at the bottom edge is nil" );
	}
	NSLog( @"----------------------------------------" );

	CGRect whereWeWere = [self rectForRowAtIndexPath: self.toIndexPathForRowBeingMoved];
	if( CGRectGetMinY(self.snapShotOfCellBeingMoved.frame) < CGRectGetMinY(whereWeWere) ) {
		// How do I check if the top edge is in a header or footer
		// between sections? Maybe be getting the edges of the where we
		// were and the next adjacent cell in this direction and checking
		// for a gap? What about if there are skipped rows or sections?
		// This deals with non-contiguity very poorly!
		if( self.toIndexPathForRowBeingMoved.section > 0 && self.toIndexPathForRowBeingMoved.row == 0 ) {
			// Could possibly be in a header or footer...
			CGFloat bottomOfLastRowOfPreviousSection;
			NSInteger previousSectionRowCount = [self numberOfRowsInSection: self.toIndexPathForRowBeingMoved.section - 1];
		//	if( previousSectionRowCount > 0 ) {
		//		CGRect bottomRowRect = [self rectForRowAtIndexPath: [NSIndexPath indexPathForRow: previousSectionRowCount - 1 inSection: self.toIndexPathForRowBeingMoved.section - 1]];
		//		bottomOfLastRowOfPreviousSection = CGRectGetMaxY( bottomRowRect );
		//	} else {
				CGRect footerRect = [self rectForFooterInSection: self.toIndexPathForRowBeingMoved.section - 1];
				bottomOfLastRowOfPreviousSection = CGRectGetMinY( footerRect );
		//	}
			CGFloat gap = CGRectGetMinY(whereWeWere) - bottomOfLastRowOfPreviousSection;
			NSLog( @"The gap between the last row of the previous section and the top row of the current section is %g", gap );
			// What if the user has moved beyond the gap into the next row or two sections back...?
			if( gap > 0.0 && CGRectGetMinY(self.snapShotOfCellBeingMoved.frame) <= CGRectGetMinY(whereWeWere) - (gap / 2.0)) {
				NSIndexPath *indexPathOfLocation = [NSIndexPath indexPathForRow: previousSectionRowCount inSection: self.toIndexPathForRowBeingMoved.section - 1];
				// Adjust the destination based on the delegate method
				if( [self.delegate respondsToSelector: @selector(tableView:targetIndexPathForMoveFromRowAtIndexPath:toProposedIndexPath:)] ) {
					indexPathOfLocation = [self.delegate tableView: self targetIndexPathForMoveFromRowAtIndexPath: self.fromIndexPathOfRowBeingMoved toProposedIndexPath: indexPathOfLocation];
				}
				
				// See if the destination row is different from the source
				if( [self.toIndexPathForRowBeingMoved compare: indexPathOfLocation] != NSOrderedSame ) {
					[self movePlaceHolderRowFromIndexPath: self.toIndexPathForRowBeingMoved toIndexPath: indexPathOfLocation];
				}
			}
		}
		NSIndexPath *indexPathOfLocation = [self indexPathForRowAtPoint: CGPointMake(CGRectGetMidX(self.snapShotOfCellBeingMoved.frame), CGRectGetMinY(self.snapShotOfCellBeingMoved.frame))];
		if( indexPathOfLocation ) {
			// Adjust the destination based on the delegate method
			if( [self.delegate respondsToSelector: @selector(tableView:targetIndexPathForMoveFromRowAtIndexPath:toProposedIndexPath:)] ) {
				indexPathOfLocation = [self.delegate tableView: self targetIndexPathForMoveFromRowAtIndexPath: self.fromIndexPathOfRowBeingMoved toProposedIndexPath: indexPathOfLocation];
			}
			
			// See if the destination row is different from the source
			if( [self.toIndexPathForRowBeingMoved compare: indexPathOfLocation] != NSOrderedSame ) {
				CGRect whereWeMightGo = [self rectForRowAtIndexPath: indexPathOfLocation];
				if( CGRectGetMinY(self.snapShotOfCellBeingMoved.frame) <= CGRectGetMidY(whereWeMightGo) ) {
					[self movePlaceHolderRowFromIndexPath: self.toIndexPathForRowBeingMoved toIndexPath: indexPathOfLocation];
				}
			}
		}
	} else if( CGRectGetMaxY(self.snapShotOfCellBeingMoved.frame) > CGRectGetMaxY(whereWeWere) ) {
		// How do I check if the bottom edge is in a footer or header
		// between sections? Maybe be getting the edges of the where we
		// were and the next adjacent cell in this direction and checking
		// for a gap?
		NSInteger sectionCount = self.numberOfSections;
		NSInteger rowsInSection = [self numberOfRowsInSection: self.toIndexPathForRowBeingMoved.section];
		if( self.toIndexPathForRowBeingMoved.section < sectionCount - 1 && self.toIndexPathForRowBeingMoved.row == rowsInSection - 1 ) {
			// Could possibly be in a header or footer...
			CGFloat topOfFirstRowOfNextSection;
			if( [self numberOfRowsInSection: self.toIndexPathForRowBeingMoved.section + 1] > 0 ) {
				CGRect topRowRect = [self rectForRowAtIndexPath: [NSIndexPath indexPathForRow: 0 inSection: self.toIndexPathForRowBeingMoved.section + 1]];
				topOfFirstRowOfNextSection = CGRectGetMinY( topRowRect );
			} else {
				CGRect headerRect = [self rectForHeaderInSection: self.toIndexPathForRowBeingMoved.section + 1];
				topOfFirstRowOfNextSection = CGRectGetMaxY( headerRect );
			}
			CGFloat gap = topOfFirstRowOfNextSection - CGRectGetMaxY( whereWeWere );
			NSLog( @"The gap between the last row of the current section and the first row of the next section is %g", gap );
			// What if the user has moved beyond the gap into the next row or the two sections back...?
			if( gap > 0.0 && CGRectGetMaxY(self.snapShotOfCellBeingMoved.frame) >= CGRectGetMaxY(whereWeWere) + (gap / 2.0)) {
				NSIndexPath *indexPathOfLocation = [NSIndexPath indexPathForRow: 0 inSection: self.toIndexPathForRowBeingMoved.section + 1];
				// Adjust the destination based on the delegate method
				if( [self.delegate respondsToSelector: @selector(tableView:targetIndexPathForMoveFromRowAtIndexPath:toProposedIndexPath:)] ) {
					indexPathOfLocation = [self.delegate tableView: self targetIndexPathForMoveFromRowAtIndexPath: self.fromIndexPathOfRowBeingMoved toProposedIndexPath: indexPathOfLocation];
				}
				
				// See if the destination row is different from the source
				if( [self.toIndexPathForRowBeingMoved compare: indexPathOfLocation] != NSOrderedSame ) {
					[self movePlaceHolderRowFromIndexPath: self.toIndexPathForRowBeingMoved toIndexPath: indexPathOfLocation];
				}
			}
		}
		NSIndexPath *indexPathOfLocation = [self indexPathForRowAtPoint: CGPointMake(CGRectGetMidX(self.snapShotOfCellBeingMoved.frame), CGRectGetMaxY(self.snapShotOfCellBeingMoved.frame))];
		if( indexPathOfLocation ) {
			// Adjust the destination based on the delegate method
			if( [self.delegate respondsToSelector: @selector(tableView:targetIndexPathForMoveFromRowAtIndexPath:toProposedIndexPath:)] ) {
				indexPathOfLocation = [self.delegate tableView: self targetIndexPathForMoveFromRowAtIndexPath: self.fromIndexPathOfRowBeingMoved toProposedIndexPath: indexPathOfLocation];
			}
			
			// See if the destination row is different from the source
			if( [self.toIndexPathForRowBeingMoved compare: indexPathOfLocation] != NSOrderedSame ) {
				CGRect whereWeMightGo = [self rectForRowAtIndexPath: indexPathOfLocation];
				if( CGRectGetMaxY(self.snapShotOfCellBeingMoved.frame) >= CGRectGetMidY(whereWeMightGo) ) {
					[self movePlaceHolderRowFromIndexPath: self.toIndexPathForRowBeingMoved toIndexPath: indexPathOfLocation];
				}
			}
		}
	}
#else
	//NSIndexPath *indexPathOfLocation = [tableView indexPathForRowAtPoint: point];
	NSIndexPath *indexPathOfLocation = [tableView indexPathForRowAtPoint: self.snapShotOfCellBeingMoved.center];
	
	// For better between segment function I should test if the top (or
	// bottom if moving down) of the snapShot reaches the center of the
	// combined section header and footer heights (or maybe the average
	// of the bottom of the last row of the section above and the first
	// row of the section below). I would want to test this
	
	// If the touch point is on a header or footer it might return nil
	if( indexPathOfLocation ) {
		// Adjust the destination based on the delegate method
		if( [tableView.delegate respondsToSelector: @selector(tableView:targetIndexPathForMoveFromRowAtIndexPath:toProposedIndexPath:)] ) {
			indexPathOfLocation = [tableView.delegate tableView: tableView targetIndexPathForMoveFromRowAtIndexPath: self.fromIndexPathOfRowBeingMoved toProposedIndexPath: indexPathOfLocation];
		}
		
		// See if the destination row is different from the source
		if( [self.toIndexPathForRowBeingMoved compare: indexPathOfLocation] != NSOrderedSame ) {
			UITableViewCell *cellAtLocation = [tableView cellForRowAtIndexPath: indexPathOfLocation];
			NSLog( @"The moving row is over row %d in section %d and the current moveTo row is %d in section %d", indexPathOfLocation.row, indexPathOfLocation.section, self.toIndexPathForRowBeingMoved.row, self.toIndexPathForRowBeingMoved.section );
			NSLog( @"- It is%s below and the snapShot center is at %g over a row with center %g", [self rowAtIndexPath: self.toIndexPathForRowBeingMoved isBelowRowAtIndexPath: indexPathOfLocation] ? "" : " not", self.snapShotOfCellBeingMoved.center.y, cellAtLocation.center.y );
			NSLog( @"- It is%s above and the snapShot center is at %g over a row with center %g", [self rowAtIndexPath: self.toIndexPathForRowBeingMoved isAboveRowAtIndexPath: indexPathOfLocation] ? "" : " not", self.snapShotOfCellBeingMoved.center.y, cellAtLocation.center.y );
			if( (self.toIndexPathForRowBeingMoved.section > indexPathOfLocation.section &&
			     self.snapShotOfCellBeingMoved.center.y > cellAtLocation.center.y) ) {
				NSIndexPath *insertLocation = [NSIndexPath indexPathForRow: indexPathOfLocation.row + 1 inSection: indexPathOfLocation.section];
				NSLog( @"Will move to row %d in section %d", indexPathOfLocation.row, indexPathOfLocation.section );
				[tableView beginUpdates];
				[tableView deleteRowsAtIndexPaths: @[self.toIndexPathForRowBeingMoved] withRowAnimation: UITableViewRowAnimationRight];
				[tableView insertRowsAtIndexPaths: @[insertLocation] withRowAnimation: UITableViewRowAnimationLeft];
				self.toIndexPathForRowBeingMoved = insertLocation;
				[tableView endUpdates];
			} else if( (self.toIndexPathForRowBeingMoved.section < indexPathOfLocation.section &&
				    self.snapShotOfCellBeingMoved.center.y < cellAtLocation.center.y ) ) {
				NSLog( @"Will move to row %d in section %d", indexPathOfLocation.row, indexPathOfLocation.section );
				[tableView beginUpdates];
				[tableView deleteRowsAtIndexPaths: @[self.toIndexPathForRowBeingMoved] withRowAnimation: UITableViewRowAnimationRight];
				[tableView insertRowsAtIndexPaths: @[indexPathOfLocation] withRowAnimation: UITableViewRowAnimationLeft];
				self.toIndexPathForRowBeingMoved = indexPathOfLocation;
				[tableView endUpdates];
			} else if(
#if 1
				  // When top reaches center
				  ([self rowAtIndexPath: self.toIndexPathForRowBeingMoved isBelowRowAtIndexPath: indexPathOfLocation] &&
				   CGRectGetMinY(self.snapShotOfCellBeingMoved.frame) <= cellAtLocation.center.y) ||
				  ([self rowAtIndexPath: self.toIndexPathForRowBeingMoved isAboveRowAtIndexPath: indexPathOfLocation] &&
				   CGRectGetMaxY(self.snapShotOfCellBeingMoved.frame) >= cellAtLocation.center.y)
#elif 0
				  // When center reaches bottom (jitters when little row moved over tall row)
				  ([self rowAtIndexPath: self.toIndexPathForRowBeingMoved isBelowRowAtIndexPath: indexPathOfLocation] &&
				   self.snapShotOfCellBeingMoved.center.y < CGRectGetMaxY(cellAtLocation.frame)) ||
				  ([self rowAtIndexPath: self.toIndexPathForRowBeingMoved isAboveRowAtIndexPath: indexPathOfLocation] &&
				   self.snapShotOfCellBeingMoved.center.y > CGRectGetMinY(cellAtLocation.frame))
#else
				  // When center reaches center (does not look good, too much overlap)
				  ([self rowAtIndexPath: self.toIndexPathForRowBeingMoved isBelowRowAtIndexPath: indexPathOfLocation] &&
				   self.snapShotOfCellBeingMoved.center.y < cellAtLocation.center.y) ||
				  ([self rowAtIndexPath: self.toIndexPathForRowBeingMoved isAboveRowAtIndexPath: indexPathOfLocation] &&
				   self.snapShotOfCellBeingMoved.center.y > cellAtLocation.center.y)
#endif
				  ) {
				NSLog( @"Will move to row %d in section %d", indexPathOfLocation.row, indexPathOfLocation.section );
#if 0
				// Use move instead of delete and insert
				// (Looks pretty bad, continue to use delete and insert)
				[tableView beginUpdates];
				[tableView moveRowAtIndexPath: self.toIndexPathForRowBeingMoved toIndexPath: indexPathOfLocation];
				self.toIndexPathForRowBeingMoved = indexPathOfLocation;
				[tableView endUpdates];
#else
				UITableViewRowAnimation delAnimation;
				UITableViewRowAnimation insAnimation;
				if( [self rowAtIndexPath: indexPathOfLocation isAboveRowAtIndexPath: self.toIndexPathForRowBeingMoved] ) {
					NSLog( @"---- moving up animations." );
					delAnimation = UITableViewRowAnimationFade;
					insAnimation = UITableViewRowAnimationNone;
				} else {
					NSLog( @"---- moving down animations." );
					delAnimation = UITableViewRowAnimationFade;
					insAnimation = UITableViewRowAnimationNone;
				}
				[tableView beginUpdates];
				[tableView deleteRowsAtIndexPaths: @[self.toIndexPathForRowBeingMoved] withRowAnimation: delAnimation];
				[tableView insertRowsAtIndexPaths: @[indexPathOfLocation] withRowAnimation: insAnimation];
				self.toIndexPathForRowBeingMoved = indexPathOfLocation;
				[tableView endUpdates];
#endif
				//for( NSInteger section = 0; section < tableView.numberOfSections; ++section ) {
				//	NSInteger rowCount = [self tableView: tableView moveAdjustedRowCount: [tableView numberOfRowsInSection: section] forSection: section];
				//	for( NSInteger row = 0; row < rowCount; ++row ) {
				//		NSIndexPath *dSource = [self tableView: tableView dataSourceIndexPathFromVisibleIndexPath: [NSIndexPath indexPathForRow: row inSection: section]];
				//		NSLog( @"Screen row %d in section %d gets data source row %d from section %d", row, section, dSource.row, dSource.section );
				//	}
				//}
			}
		}
	}
#endif
}
- (void) movePlaceHolderRowFromIndexPath: (NSIndexPath *) fromIndexPath toIndexPath: (NSIndexPath *) toIndexPath {
	if( fromIndexPath.length < 2 || toIndexPath.length < 2 ) {
		NSLog( @"***** error: bad fromIndexPath or toIndexPath passed to %s", __func__ );
		return;
	}
#if 0
	// Use move instead of delete and insert
	// (Looks pretty bad, continue to use delete and insert)
	[self beginUpdates];
	[self moveRowAtIndexPath: fromIndexPath toIndexPath: toIndexPath];
	self.toIndexPathForRowBeingMoved = toIndexPath;
	[self endUpdates];
#else
	UITableViewRowAnimation delAnimation;
	UITableViewRowAnimation insAnimation;
	if( [toIndexPath isAboveRowAtIndexPath: fromIndexPath] ) {
		NSLog( @"---- moving up animations." );
		delAnimation = UITableViewRowAnimationFade;
		insAnimation = UITableViewRowAnimationNone;
	} else {
		NSLog( @"---- moving down animations." );
		delAnimation = UITableViewRowAnimationFade;
		insAnimation = UITableViewRowAnimationNone;
	}
	if( [self.delegate respondsToSelector: @selector(tableView:willMovePlaceHolderFromIndexPath:toIndexPath:)] ) {
		[(id) self.delegate tableView: self willMovePlaceHolderFromIndexPath: fromIndexPath toIndexPath: toIndexPath];
	}
	[self beginUpdates];
	[self deleteRowsAtIndexPaths: @[fromIndexPath] withRowAnimation: delAnimation];
	[self insertRowsAtIndexPaths: @[toIndexPath] withRowAnimation: insAnimation];
	self.toIndexPathForRowBeingMoved = toIndexPath;
	[self endUpdates];
	if( [self.delegate respondsToSelector: @selector(tableView:didMovePlaceHolderFromIndexPath:toIndexPath:)] ) {
		[(id) self.delegate tableView: self didMovePlaceHolderFromIndexPath: fromIndexPath toIndexPath: toIndexPath];
	}
#endif
}
- (void) finishMovingRowToPoint: (CGPoint) point  {
	// If we are scrolling, stop
	[self.reorderAutoScrollTimer invalidate];
	self.reorderAutoScrollTimer = nil;
	self.reorderAutoScrollRate = 0;

	// We are finished so we are moving to the toIndexPathForRowBeingMoved
	if( self.toIndexPathForRowBeingMoved ) {
		// Get the cell coordinates so we know where its center is
		UITableViewCell *endCell = [self cellForRowAtIndexPath: self.toIndexPathForRowBeingMoved];
		// Make the snap shot cell nicely disappear
		[UIView animateWithDuration: 0.25 animations: ^{
			self.snapShotOfCellBeingMoved.center = CGPointMake( self.snapShotOfCellBeingMoved.center.x, endCell.center.y );
		} completion: ^( BOOL finished ) {
			// Clear 'snapShotOfCellBeingMoved' so the cell will
			// draw instead of drawing a blank space.
			UIView *tempSnapShotHolder = self.snapShotOfCellBeingMoved;
			self.snapShotOfCellBeingMoved = nil;
			[self reloadRowsAtIndexPaths: @[self.toIndexPathForRowBeingMoved] withRowAnimation: UITableViewRowAnimationNone];
			// Maybe I should delay this removal or animate it to
			// prevent flicker? Animate its alpha to zero then remove?
			[UIView animateWithDuration: 0.1 animations:^{
				tempSnapShotHolder.alpha = 0.0;
			} completion:^(BOOL finished) {
				[tempSnapShotHolder removeFromSuperview];
			}];

			// Tell the table view's datasource the the row has been
			// moved so it can make the datasource match the display
			if( [self.dataSource respondsToSelector: @selector(tableView:moveRowAtIndexPath:toIndexPath:)] ) {
				[self.dataSource tableView: self moveRowAtIndexPath: self.fromIndexPathOfRowBeingMoved toIndexPath: self.toIndexPathForRowBeingMoved];
			}

			self.fromIndexPathOfRowBeingMoved = nil;
			self.toIndexPathForRowBeingMoved = nil;
		}];
	}
}

// Alternative on cancel:
// 1. Put things back the way they were when we started.
// 2. Leave things right where they are right now, in mid move.
- (void) cancelMovingRowAtPoint: (CGPoint) point {
	if( [self.delegate respondsToSelector: @selector(cancelLongPressMoveResetsToOriginalState)] &&
	    [(id) self.delegate cancelLongPressMoveResetsToOriginalState] ) {
		NSLog( @"Moving cancelled, reseting to original state." );
		UIView *tempSnapShotHolder = self.snapShotOfCellBeingMoved;
		self.snapShotOfCellBeingMoved = nil;
		// See if the destination row is different from the source
		if( self.toIndexPathForRowBeingMoved && self.fromIndexPathOfRowBeingMoved &&
		   [self.toIndexPathForRowBeingMoved compare: self.fromIndexPathOfRowBeingMoved] != NSOrderedSame ) {
			[self beginUpdates];
			[self deleteRowsAtIndexPaths: @[self.toIndexPathForRowBeingMoved] withRowAnimation: UITableViewRowAnimationNone];
			[self insertRowsAtIndexPaths: @[self.fromIndexPathOfRowBeingMoved] withRowAnimation: UITableViewRowAnimationNone];
			[self endUpdates];
		}
		[tempSnapShotHolder removeFromSuperview];
		self.toIndexPathForRowBeingMoved = nil;
		self.fromIndexPathOfRowBeingMoved = nil;
		[self.reorderAutoScrollTimer invalidate];
		self.reorderAutoScrollTimer = nil;
	} else {
		NSLog( @"Moving cancelled but calling finish." );
		[self finishMovingRowToPoint: point];
	}
}

- (UIView *) snapShotViewOfCellAtIndexPath: (NSIndexPath *) indexPath {
	if( [self.delegate respondsToSelector: @selector(tableView:snapShotViewOfCellAtIndexPath:)] ) {
		return [(id) self.delegate tableView: self snapShotViewOfCellAtIndexPath: indexPath];
	} else {
#if 1
	UITableViewCell *touchedCell = [self cellForRowAtIndexPath: indexPath];
	touchedCell.highlighted = NO;
	touchedCell.selected = NO;
	
	// snapshotViewAfterScreenUpdates: is an iOS 7 introduced method!
	UIView *snapShot;
	if( [touchedCell respondsToSelector: @selector(snapshotViewAfterScreenUpdates:)] ) {
		snapShot = [touchedCell snapshotViewAfterScreenUpdates: YES];
		snapShot.frame = touchedCell.frame;
		snapShot.alpha = 0.70;
		snapShot.layer.shadowOpacity = 1.0;
		snapShot.layer.shadowRadius = 4.0;
		snapShot.layer.shadowOffset = CGSizeMake( 0, 1.5 );
		// Looks the same or better without the shadows path
		//snapShot.layer.shadowPath = [[UIBezierPath bezierPathWithRect:snapShot.layer.bounds] CGPath];
	} else {
		// make an image from the pressed tableview cell
		UIGraphicsBeginImageContextWithOptions( touchedCell.bounds.size, NO, 0 );
		[touchedCell.layer renderInContext:UIGraphicsGetCurrentContext()];
		UIImage *cellImage = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
		snapShot = [[UIImageView alloc] initWithImage: cellImage];
		snapShot.frame = touchedCell.frame;
#if 0	// Too gray....
		snapShot.alpha = 0.70;
		snapShot.layer.shadowOpacity = 1.0;
		snapShot.layer.shadowRadius = 4.0;
		snapShot.layer.shadowOffset = CGSizeMake( 0, 1.5 );
		snapShot.layer.shadowPath = [[UIBezierPath bezierPathWithRect: snapShot.layer.bounds] CGPath];
#elif 1	// Doing the rasterize gets the gray out...
		snapShot.alpha = 0.70;
		snapShot.layer.shadowOpacity = 1.0;
		snapShot.layer.shadowRadius = 4.0;
		snapShot.layer.shadowOffset = CGSizeMake( 0, 1.5 );
		// Looks better without the shadows path
		//snapShot.layer.shadowPath = [[UIBezierPath bezierPathWithRect: snapShot.layer.bounds] CGPath];
		
		snapShot.layer.rasterizationScale = [[UIScreen mainScreen] scale];
		snapShot.layer.shouldRasterize = YES;
		//
#elif 0	// Also too gray...
		// add drop shadow to image and lower opacity
		snapShot.layer.masksToBounds = NO;
		snapShot.layer.opacity = 0.6;
		snapShot.layer.shadowOpacity = 0.7;
		snapShot.layer.shadowRadius = 3.0;
		snapShot.layer.shadowColor = [[UIColor blackColor] CGColor];
		snapShot.layer.shadowOffset = CGSizeMake( 0, 1 );
#else	// Shadows are two horizontal lines...
		CGFloat shadowHeight = 10.0;
		CGRect shadowRect = touchedCell.bounds;
		shadowRect.origin.y = -shadowHeight;
		shadowRect.size.height = shadowHeight;
		CGRect shadowClippingRect = touchedCell.bounds;
		shadowClippingRect.origin.y = shadowHeight;
		
		UIBezierPath *topShadowPath = [UIBezierPath bezierPathWithRect: shadowClippingRect];
		
		UIView *shadowView = [[UIView alloc] initWithFrame: shadowRect];
		shadowView.backgroundColor = [UIColor clearColor];
		shadowView.opaque = NO;
		shadowView.clipsToBounds = YES;
		
		shadowView.layer.shadowPath = topShadowPath.CGPath;
		shadowView.layer.shadowOpacity = 0.7;
		shadowView.layer.shadowOffset = CGSizeMake( 0, 0 );
		shadowView.layer.shadowRadius = 3.0;
		
		[snapShot addSubview: shadowView];
		
		shadowRect.origin.y = touchedCell.bounds.origin.y + touchedCell.bounds.size.height;
		shadowClippingRect.origin.y = -shadowRect.origin.y;
		
		UIBezierPath *bottomShadowPath = [UIBezierPath bezierPathWithRect: shadowClippingRect];
		
		shadowView = [[UIView alloc] initWithFrame: shadowRect];
		shadowView.backgroundColor = [UIColor clearColor];
		shadowView.opaque = NO;
		shadowView.clipsToBounds = YES;
		
		shadowView.layer.shadowPath = bottomShadowPath.CGPath;
		shadowView.layer.shadowOpacity = 0.7;
		shadowView.layer.shadowOffset = CGSizeMake( 0, 0 );
		shadowView.layer.shadowRadius = 3.0;
		
		[snapShot addSubview: shadowView];
#endif
	}
	return snapShot;
#else
	UITableViewCell *touchedCell = [self.dataSource tableView: self cellForRowAtIndexPath: indexPath];
	touchedCell.frame = [self rectForRowAtIndexPath: indexPath];
	touchedCell.backgroundColor = [UIColor whiteColor];
	touchedCell.layer.opacity = 0.6;
	touchedCell.layer.shadowOpacity = 1.0;
	touchedCell.layer.shadowRadius = 4.0;
	touchedCell.layer.shadowOffset = CGSizeMake( 0, 1.5 );
	touchedCell.layer.shadowPath = [[UIBezierPath bezierPathWithRect: touchedCell.layer.bounds] CGPath];
	touchedCell.layer.rasterizationScale = [[UIScreen mainScreen] scale];
	touchedCell.layer.shouldRasterize = YES;
	return touchedCell;
#endif
	}
}

- (void) reorderAutoScrollTimerFired: (id) timer {
#if 0
	// Make sure the autoscroll distance is legal
	CGFloat minimumLegalDistance = self.tableView.contentOffset.y * -1.0;
	CGFloat maximumLegalDistance = self.tableView.contentSize.height - (CGRectGetHeight(self.tableView.frame) + self.tableView.contentOffset.y);
	self.autoscrollDistance = MAX( self.autoscrollDistance, minimumLegalDistance );
	self.autoscrollDistance = MIN( self.autoscrollDistance, maximumLegalDistance );
	
	// Scroll the tableview...
	CGPoint contentOffset = self.tableView.contentOffset;
	contentOffset.y += self.autoscrollDistance;
	self.tableView.contentOffset = contentOffset;
	
	// Counter move the snapshot view so scrolling does not move it...
	self.snapShotOfCellBeingMoved.center = CGPointMake( self.snapShotOfCellBeingMoved.center.x, self.snapShotOfCellBeingMoved.center.y + self.autoscrollDistance );
	
	[self moveRowIfNeededInTableView: self.tableView];
#else
	CGPoint currentOffset = self.contentOffset;
	CGPoint newOffset = CGPointMake( currentOffset.x, currentOffset.y + self.reorderAutoScrollRate * MAX_SCROLL_RATE );
	NSLog( @"~~ Changing content offset from %g to %g, scrollRate is %g", currentOffset.y, newOffset.y, self.reorderAutoScrollRate );
	
	if( newOffset.y < -self.contentInset.top ) {
		newOffset.y = -self.contentInset.top;
		NSLog( @"   ~~ Oops, it was < -contentInset.top (%g), so changed to %g", -self.contentInset.top, newOffset.y );
		// We hit the top, don't need to scroll anymore, so invalidate the timer.
		// This does not set the self.reorderAutoScrollTimer to nil. This could
		// lead to problems with restarting it if I transition immediately
		// to trying to scroll down without any snapShot cell movement
		// outside a scroll zone. It seems like this could only happen
		// if the table height was very small and a row height was very
		// big... what about landscape?
		[timer invalidate];
		self.reorderAutoScrollTimer = nil;
	} else if( self.contentSize.height + self.contentInset.bottom < self.frame.size.height ) {
		newOffset = currentOffset;
		NSLog( @"   ~~ Oops, contentSize.height (%g) + contentInset.bottom (%g) < frame.size.height (%g) so reset to %g", self.contentSize.height, self.contentInset.bottom, self.frame.size.height, newOffset.y );
	} else if( newOffset.y > (self.contentSize.height + self.contentInset.bottom - self.frame.size.height) ) {
		newOffset.y = (self.contentSize.height + self.contentInset.bottom - self.frame.size.height);
		NSLog( @"   ~~ Oops, it was > contentSize.height (%g) + contentInset.bottom (%g) - frame.size.height (%g), so changed to %g", self.contentSize.height, self.contentInset.bottom, self.frame.size.height, newOffset.y );
		// We hit the bottom, don't need to scroll anymore, so invalidate the timer.
		[timer invalidate];
		self.reorderAutoScrollTimer = nil;
	}
	// Set the content offset to the bounds checked value. Even though it
	// does not seem to be in the documentation, contentOffset seems to get
	// rounded to an integer number of pixels (so on a non-retina display
	// gets rounded to a whole number, on a retina display gets rounded to
	// the 0.5). So rather than using 'netOffset' to calculate move distance
	// I will pull it from the contentOffset after setting it.
	self.contentOffset = newOffset;
	NSLog( @"~~ Set contentOffset to %g and it is %g", newOffset.y, self.contentOffset.y );
	CGFloat moveDistance = self.contentOffset.y - currentOffset.y;
	
	//if( location.y >= 0 && location.y <= self.tableView.contentSize.height + 50) {
	//	self.snapShotOfCellBeingMoved.center = CGPointMake( self.tableView.center.x, location.y );
	//}
	if( moveDistance != 0.0 ) {
		CGFloat newCenterY = self.snapShotOfCellBeingMoved.center.y + moveDistance;
		if( newCenterY < self.contentOffset.y + self.contentInset.top )
			newCenterY = self.contentOffset.y + self.contentInset.top;
		if( newCenterY > CGRectGetMaxY(self.bounds) - self.contentInset.bottom )
			newCenterY = CGRectGetMaxY(self.bounds) - self.contentInset.bottom;
		self.snapShotOfCellBeingMoved.center = CGPointMake( self.snapShotOfCellBeingMoved.center.x, newCenterY );
		[self movePlaceHolderRowIfNeeded];
	}
#endif
}

#pragma mark - Public methods for interfacing with the reordering methods
- (NSIndexPath *) dataSourceIndexPathFromVisibleIndexPath: (NSIndexPath *) indexPath {
	// Both the to and from locations should be set if we are in a move
	// or either the source or the destination need to be in the section
	// for any of its indeces to have been affected.
	if( !self.toIndexPathForRowBeingMoved || !self.fromIndexPathOfRowBeingMoved ||
	   (indexPath.section != self.toIndexPathForRowBeingMoved.section &&
	    indexPath.section != self.fromIndexPathOfRowBeingMoved.section) ) {
		   //NSLog( @"No index path translation needed, not in a move or in a section without the to or from rows" );
		   return indexPath;
	   }
	// So both the toIndex and fromIndex are defined and the indexPath is in one of them
	// If indexPath == toMoveLocation, the it gets the fromMoveIndex
	if( indexPath.section == self.toIndexPathForRowBeingMoved.section &&
	    indexPath.row     == self.toIndexPathForRowBeingMoved.row ) {
		//NSLog( @"In a move and a request for the destination cell, so return the index path of the original position" );
		return self.fromIndexPathOfRowBeingMoved;
	}
	if( self.fromIndexPathOfRowBeingMoved.section == self.toIndexPathForRowBeingMoved.section ) {
		//NSLog( @"In a move and both the source and destination rows are in the same section" );
		if( self.fromIndexPathOfRowBeingMoved.row < self.toIndexPathForRowBeingMoved.row ) {
			if( indexPath.row >= self.fromIndexPathOfRowBeingMoved.row &&
			    indexPath.row  < self.toIndexPathForRowBeingMoved.row ) {
				return [NSIndexPath indexPathForRow: indexPath.row + 1 inSection: indexPath.section];
			}
		} else {
			if( indexPath.row > self.toIndexPathForRowBeingMoved.row &&
			   indexPath.row <= self.fromIndexPathOfRowBeingMoved.row ) {
				return [NSIndexPath indexPathForRow: indexPath.row - 1 inSection: indexPath.section];
			}
		}
	} else if( indexPath.section == self.toIndexPathForRowBeingMoved.section ) {
		if( indexPath.row > self.toIndexPathForRowBeingMoved.row ) {
			return [NSIndexPath indexPathForRow: indexPath.row - 1 inSection: indexPath.section];
		}
	} else if( indexPath.section == self.fromIndexPathOfRowBeingMoved.section ) {
		if( indexPath.row >= self.fromIndexPathOfRowBeingMoved.row ) {
			return [NSIndexPath indexPathForRow: indexPath.row + 1 inSection: indexPath.section];
		}
	}
	return indexPath;
}
// This is a helper routine to fix the number of rows in the section as the
// moving row crosses in and out of sections...
- (NSInteger) adjustedValueForReorderingOfRowCount: (NSInteger) rowCount forSection: (NSInteger) section {
	if( section == self.fromIndexPathOfRowBeingMoved.section &&
	    self.toIndexPathForRowBeingMoved.section != self.fromIndexPathOfRowBeingMoved.section ) {
		--rowCount;
	} else if( section == self.toIndexPathForRowBeingMoved.section &&
		   self.toIndexPathForRowBeingMoved.section != self.fromIndexPathOfRowBeingMoved.section ) {
		++rowCount;
	}
	return rowCount;
}

- (BOOL) shouldSubstitutePlaceHolderForCellBeingMovedAtIndexPath: (NSIndexPath *) indexPath {
	return( self.fromIndexPathOfRowBeingMoved && self.toIndexPathForRowBeingMoved &&
	        self.snapShotOfCellBeingMoved &&
	       [indexPath compare: self.fromIndexPathOfRowBeingMoved] == NSOrderedSame );
}


#pragma mark - Getters and Setters for added properties (using associated objects)

static void *rowReorderGestureRecognizerKey = &rowReorderGestureRecognizerKey;
- (UILongPressGestureRecognizer *) rowReorderGestureRecognizer {
	UILongPressGestureRecognizer *g = objc_getAssociatedObject( self, rowReorderGestureRecognizerKey );
	return g;
}
- (void) setRowReorderGestureRecognizer: (UILongPressGestureRecognizer *) rowReorderGestureRecognizer {
	//NSLog( @"Entering %s", __func__ );
	//NSLog( @"- The tableview has %d gesture recognizers", self.gestureRecognizers.count );
	//NSLog( @"  They are:\n  -- %@", [self.gestureRecognizers componentsJoinedByString: @"\n  -- "] );
	UILongPressGestureRecognizer *g = objc_getAssociatedObject( self, rowReorderGestureRecognizerKey );
	if( ![g isEqual: rowReorderGestureRecognizer] ) {
		if( rowReorderGestureRecognizer ) {
			objc_setAssociatedObject( self, rowReorderGestureRecognizerKey, rowReorderGestureRecognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
			[self addGestureRecognizer: rowReorderGestureRecognizer];
			//NSLog( @"-- Set the gesture recognizer and added it to the tableView" );
		} else if( g && !self.allowsLongPressToReorder && !self.allowsLongPressToReorderDuringEditing ) {
			objc_setAssociatedObject( self, rowReorderGestureRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
			[self removeGestureRecognizer: g];
			//NSLog( @"-- Set the gesture recognizer to nil and removed it from the tableView" );
		}
	}
}

static void *delegateForRowReorderGestureRecognizerKey = &delegateForRowReorderGestureRecognizerKey;
- (id <UIGestureRecognizerDelegate>) delegateForRowReorderGestureRecognizer {
	id <UIGestureRecognizerDelegate> d = objc_getAssociatedObject( self, delegateForRowReorderGestureRecognizerKey );
	return d;
}
- (void) setDelegateForRowReorderGestureRecognizer: (id <UIGestureRecognizerDelegate>) delegateForRowReorderGestureRecognizer {
	objc_setAssociatedObject( self, delegateForRowReorderGestureRecognizerKey, delegateForRowReorderGestureRecognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC );
}

static void *snapShotOfCellBeingMovedKey = &snapShotOfCellBeingMovedKey;
- (UIView *) snapShotOfCellBeingMoved {
	UIView *v = objc_getAssociatedObject( self, snapShotOfCellBeingMovedKey );
	return v;
}
- (void) setSnapShotOfCellBeingMoved: (UIView *) snapShotOfCellBeingMoved {
	UIView *v = objc_getAssociatedObject( self, snapShotOfCellBeingMovedKey );
	if( v != snapShotOfCellBeingMoved ) {
		objc_setAssociatedObject( self, snapShotOfCellBeingMovedKey, snapShotOfCellBeingMoved, OBJC_ASSOCIATION_RETAIN_NONATOMIC );
	}
}

static void *fromIndexPathOfRowBeingMovedKey = &fromIndexPathOfRowBeingMovedKey;
- (NSIndexPath *) fromIndexPathOfRowBeingMoved {
	NSIndexPath *indexPath = objc_getAssociatedObject( self, fromIndexPathOfRowBeingMovedKey );
	return indexPath;
}
- (void) setFromIndexPathOfRowBeingMoved: (NSIndexPath *) fromIndexPathOfRowBeingMoved {
	NSIndexPath *indexPath = objc_getAssociatedObject( self, fromIndexPathOfRowBeingMovedKey );
	if( indexPath != fromIndexPathOfRowBeingMoved ) {
		objc_setAssociatedObject( self, fromIndexPathOfRowBeingMovedKey, fromIndexPathOfRowBeingMoved, OBJC_ASSOCIATION_RETAIN_NONATOMIC );
	}
}
static void *toIndexPathForRowBeingMovedKey = &toIndexPathForRowBeingMovedKey;
- (NSIndexPath *) toIndexPathForRowBeingMoved {
	NSIndexPath *indexPath = objc_getAssociatedObject( self, toIndexPathForRowBeingMovedKey );
	return indexPath;
}
- (void) setToIndexPathForRowBeingMoved: (NSIndexPath *) toIndexPathForRowBeingMoved {
	NSIndexPath *indexPath = objc_getAssociatedObject( self, toIndexPathForRowBeingMovedKey );
	if( indexPath != toIndexPathForRowBeingMoved ) {
		objc_setAssociatedObject( self, toIndexPathForRowBeingMovedKey, toIndexPathForRowBeingMoved, OBJC_ASSOCIATION_RETAIN_NONATOMIC );
	}
}

static void *reorderTouchOffsetKey = &reorderTouchOffsetKey;
- (CGPoint) reorderTouchOffset {
	CGPoint point = [objc_getAssociatedObject( self, reorderTouchOffsetKey ) CGPointValue];
	return point;
}
- (void) setReorderTouchOffset: (CGPoint) reorderTouchOffset {
	CGPoint point = [objc_getAssociatedObject( self, reorderTouchOffsetKey ) CGPointValue];
	if( !CGPointEqualToPoint( point, reorderTouchOffset) ) {
		objc_setAssociatedObject( self, reorderTouchOffsetKey, [NSValue valueWithCGPoint: reorderTouchOffset], OBJC_ASSOCIATION_RETAIN_NONATOMIC );
	}
}

static void *reorderAutoScrollRateKey = &reorderAutoScrollRateKey;
- (CGFloat) reorderAutoScrollRate {
	CGFloat rate = [objc_getAssociatedObject( self, reorderAutoScrollRateKey ) floatValue];
	return rate;
}
- (void) setReorderAutoScrollRate: (CGFloat) reorderAutoScrollRate {
	CGFloat rate = [objc_getAssociatedObject( self, reorderAutoScrollRateKey ) floatValue];
	if( reorderAutoScrollRate != rate ) {
		objc_setAssociatedObject( self, reorderAutoScrollRateKey, [NSNumber numberWithFloat: reorderAutoScrollRate], OBJC_ASSOCIATION_RETAIN_NONATOMIC );
	}
}

static void *reorderAutoScrollTimerKey = &reorderAutoScrollTimerKey;
- (CADisplayLink *) reorderAutoScrollTimer {
	CADisplayLink *timer = objc_getAssociatedObject( self, reorderAutoScrollTimerKey );
	return timer;
}
- (void) setReorderAutoScrollTimer: (CADisplayLink *) reorderAutoScrollTimer {
	CADisplayLink *timer = objc_getAssociatedObject( self, reorderAutoScrollTimerKey );
	if( reorderAutoScrollTimer != timer ) {
		objc_setAssociatedObject( self, reorderAutoScrollTimerKey, reorderAutoScrollTimer, OBJC_ASSOCIATION_RETAIN_NONATOMIC );
	}
}

#ifdef CONFIGURATION_VALIDATION
- (void) verifyConfiguration {
	NSLog( @"=================================================================================" );
	NSLog( @"In debug mode... lets check configuration for long press row reordering" );
	
	if( ![self.dataSource respondsToSelector: @selector(tableView:moveRowAtIndexPath:toIndexPath:)] ) {
		NSLog( @" " );
		NSLog( @"*** Warning: The tableView's datasource does not respond to" );
		NSLog( @"                'tableView:moveRowAtIndexPath:toIndexPath:'" );
		NSLog( @"             so reordering of rows is not enabled. See Apple documentaion." );
	}
	if( self.numberOfSections > 1 ) {
		NSInteger s0rc = [self.dataSource tableView: self numberOfRowsInSection: 0];
		NSInteger s1rc = [self.dataSource tableView: self numberOfRowsInSection: 1];
		if( s0rc > 0 && s1rc > 0 ) {
			self.fromIndexPathOfRowBeingMoved = [NSIndexPath indexPathForRow: 0 inSection: 0];
			self.toIndexPathForRowBeingMoved = [NSIndexPath indexPathForRow: 0 inSection: 1];
			NSInteger s0rcX = [self.dataSource tableView: self numberOfRowsInSection: 0];
			NSInteger s1rcX = [self.dataSource tableView: self numberOfRowsInSection: 1];
			if( s1rc == s1rcX || s0rc == s0rcX ) {
				NSLog( @"" );
				NSLog( @"*** Warning: The tableView datasource method 'tableView:numberOfRowsInSection:'" );
				NSLog( @"             does not appear to be adjusted for using long press for reordering." );
				NSLog( @"             Be sure to adjust the row count by returning the value of the" );
				NSLog( @"             tableView method 'adjustedValueForReorderingOfRowCount:forSection:'" );
				NSLog( @"             from the datasource method 'tableView:numberOfRowsInSection:'");
				NSLog( @"" );
				NSLog( @"             Also the indexPath passed to 'tableView:cellForRowAtIndexPath:'");
				NSLog( @"             should be modified within the method like:" );
				NSLog( @"               indexPath = [tableView dataSourceIndexPathFromVisibleIndexPath: indexPath];" );
				NSLog( @"             if not already done." );
				NSLog( @"" );
				NSLog( @"             This modification of the index path should be done for all datasource" );
				NSLog( @"             and delegate methods that are are passed an indexPath that is intended" );
				NSLog( @"             to determine the data for that row and could be called while a row is" );
				NSLog( @"             being dragged (such as 'tableView:heightForRowAtIndexPath:' and others)." );
			}
			self.fromIndexPathOfRowBeingMoved = nil;
			self.toIndexPathForRowBeingMoved = nil;
		}
	} else {
		NSLog( @" " );
		NSLog( @"The number of sections not greater than 1, so checking of datasource method:" );
		NSLog( @"  'tableView:numberOfRowsInSection:' is not possible. Be sure it utilizes the" );
		NSLog( @"tableView method 'adjustedValueForReorderingOfRowCount:forSection:' to correct" );
		NSLog( @"the row count value during a row dragging event." );
	}
	// If there are custom row heights, make sure the proper rows are being set...
	if( [self.delegate respondsToSelector: @selector(tableView:heightForRowAtIndexPath:)] ) {
		// See if I can find rows with different heights...
		CGFloat	h0;
		NSIndexPath	*indexPathForH0;
		CGFloat h1;
		NSIndexPath	*indexPathForH1;
		NSInteger sectionCount = [self.dataSource numberOfSectionsInTableView: self];
		for( NSInteger section = 0; section < sectionCount; ++section ) {
			NSInteger rowCount = [self.dataSource tableView: self numberOfRowsInSection: section];
			for( NSInteger row = 0; row < rowCount; ++row ) {
				h1 = [self.delegate tableView: self heightForRowAtIndexPath: [NSIndexPath indexPathForRow: row inSection: section]];
				if( !indexPathForH0 ) {
					indexPathForH0 = [NSIndexPath indexPathForRow: row inSection: section];
					h0 = h1;
				}
				if( h1 != h0 ) {
					indexPathForH1 = [NSIndexPath indexPathForRow: row inSection: section];
					section = sectionCount;
					break;
				}
			}
		}
		// If there are different heights, try swapping their locations and make sure heights also swap...
		if( indexPathForH0 && indexPathForH1 && h0 != h1 ) {
			//NSLog( @"The cell at row %d in section %d has a height of %g and row %d in section %d has a height of %g", indexPathForH0.row, indexPathForH0.section, h0, indexPathForH1.row, indexPathForH1.section, h1 );
			self.fromIndexPathOfRowBeingMoved = indexPathForH0;
			self.toIndexPathForRowBeingMoved = indexPathForH1;
			CGFloat h0X = [self.delegate tableView: self heightForRowAtIndexPath: indexPathForH0];
			CGFloat h1X = [self.delegate tableView: self heightForRowAtIndexPath: indexPathForH1];
			//NSLog( @"With row swap the cell at row %d in section %d has a height of %g and row %d in section %d has a height of %g", indexPathForH0.row, indexPathForH0.section, h0X, indexPathForH1.row, indexPathForH1.section, h1X );
			if( h0 != h1X || h1 != h0X ) {
				NSLog( @" " );
				NSLog( @"*** Warning: indexPath does not appear to be adjusted in tableView delegate method" );
				NSLog( @"             'tableView:heightForRowAtIndexPath:'. The index path passed to this" );
				NSLog( @"             method should be modified like:" );
				NSLog( @"               indexPath = [tableView dataSourceIndexPathFromVisibleIndexPath: indexPath];" );
				NSLog( @"             prior to determining the height for the row." );
				NSLog( @" " );
				NSLog( @"             This modification of the index path should be done for all datasource" );
				NSLog( @"             and delegate methods that are are passed an indexPath that is intended" );
				NSLog( @"             to determine the data for that row and could be called while a row is" );
				NSLog( @"             being dragged (such as 'tableView:cellForRowAtIndexPath:' and others)." );
			}
			self.fromIndexPathOfRowBeingMoved = nil;
			self.toIndexPathForRowBeingMoved = nil;
		}
	} else {
		NSLog( @" " );
		NSLog( @"The tableView delegate method 'tableView:heightForRowAtIndexPath' is not" );
		NSLog( @"implemented. This is fine but if it is added later be sure to modify the" );
		NSLog( @"indexPath like:" );
		NSLog( @"    indexPath = [tableView dataSourceIndexPathFromVisibleIndexPath: indexPath];" );
		NSLog( @"             prior to determining the height for the row." );
	}
	NSLog( @" " );
	NSLog( @"  (to turn off this checking unset CONFIGURATION_VALIDATION in" );
	NSLog( @"   %s)", __FILE__ );
	NSLog( @"=================================================================================" );
}
#endif

@end

#pragma mark - Implementation of class to perform as gesture recognizer delegate

@implementation delegateForReorderGesture

- (BOOL) gestureRecognizerShouldBegin: (UIGestureRecognizer *) gesture {
	NSLog( @"Entering %s", __func__ );
	BOOL shouldBegin = NO;
	UIView	*viewForGesture = gesture.view;
	if( ![viewForGesture isKindOfClass: [UITableView class]] ) {
		NSLog( @"- **** The attributeMoveGesture is not attached to a UITableView" );
	} else {
		UITableView *movingInTableView = (UITableView *) viewForGesture;
		
		CGPoint currentLocation = [gesture locationInView: movingInTableView];
		//NSLog( @"- The touch point is (%g,%g)", currentLocation.x, currentLocation.y );
		NSIndexPath *indexPathOfLocation = [movingInTableView indexPathForRowAtPoint: currentLocation];
		//NSLog( @"- This at index path %@", indexPathOfLocation );
		
		if( indexPathOfLocation &&
		   ((movingInTableView.editing && movingInTableView.allowsLongPressToReorderDuringEditing) ||
		    (!movingInTableView.editing && movingInTableView.allowsLongPressToReorder)) &&
		   [movingInTableView.dataSource respondsToSelector: @selector(tableView:moveRowAtIndexPath:toIndexPath:)] &&
		   (![movingInTableView.dataSource respondsToSelector: @selector(tableView:canEditRowAtIndexPath:)] ||
		    [movingInTableView.dataSource tableView: movingInTableView canEditRowAtIndexPath: indexPathOfLocation]) &&
		   (![movingInTableView.dataSource respondsToSelector: @selector(tableView:canMoveRowAtIndexPath:)] ||
		    [movingInTableView.dataSource tableView: movingInTableView canMoveRowAtIndexPath: indexPathOfLocation]) ) {
			   shouldBegin = YES;
		   }
		if( shouldBegin )
			NSLog( @"- yes it should" );
		else	NSLog( @"- no it should not" );
	}
	return shouldBegin;
}

//- (BOOL) gestureRecognizer: (UIGestureRecognizer *) gestureRecognizer shouldReceiveTouch: (UITouch *) touch {
//	return YES;
//}
//- (BOOL) gestureRecognizer:(UIGestureRecognizer *) gestureRecognizer shouldBeRequiredToFailByGestureRecognizer: (UIGestureRecognizer *) otherGestureRecognizer {
//	return YES;
//}
//- (BOOL) gestureRecognizer: (UIGestureRecognizer *) gestureRecognizer shouldRequireFailureOfGestureRecognizer: (UIGestureRecognizer *) otherGestureRecognizer {
//	return YES;
//}
//- (BOOL) gestureRecognizer: (UIGestureRecognizer *) gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer: (UIGestureRecognizer *) otherGestureRecognizer {
//	return YES;
//}

@end

@implementation NSIndexPath (Reorder)
- (BOOL) isBelowRowAtIndexPath: (NSIndexPath *) referencePath {
	return( referencePath &&
	       ((self.section  > referencePath.section) ||
		(self.section == referencePath.section && self.row > referencePath.row)));
}
- (BOOL) isAboveRowAtIndexPath: (NSIndexPath *) referencePath {
	return( referencePath &&
	       ((self.section  < referencePath.section) ||
		(self.section == referencePath.section && self.row < referencePath.row)));
}
@end
