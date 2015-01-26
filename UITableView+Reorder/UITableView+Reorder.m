//
//  UITableView+Reorder.m
//  Version 1.0.3
//
//  Created by David W. Stockton on 3/3/14.
//  Copyright (c) 2014 Syntonicity, LLC.
//

#import "UITableView+Reorder.h"
#import <objc/runtime.h>

// CONFIGURATION_VALIDATION turns on some runtime testing to help programmers
// use this category properly and automatically turns off when not in debug
#ifdef DEBUG
#define CONFIGURATION_VALIDATION
//#undef CONFIGURATION_VALIDATION
#endif

// UITABLEVIEW_REORDER_DEVELOPMENT_PROJECT is defined in the project .pch
// file for the debug and development project for UITableView+Reorder
#ifdef UITABLEVIEW_REORDER_DEVELOPMENT_PROJECT
#   define  DLog(fmt,...)	NSLog(fmt,##__VA_ARGS__)
#else
#   define  DLog(...)
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
				DLog( @"Internal long press gesture recognizer and its delegate set for reordering." );
			} else {
				self.delegateForRowReorderGestureRecognizer = nil;
				self.rowReorderGestureRecognizer = nil;
				DLog( @"Internal long press gesture recognizer and its delegate cleared for reordering." );
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
				DLog( @"Internal long press gesture recognizer and its delegate set for reordering." );
			} else {
				self.delegateForRowReorderGestureRecognizer = nil;
				self.rowReorderGestureRecognizer = nil;
				DLog( @"Internal long press gesture recognizer and its delegate cleared for reordering." );
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
			DLog( @"Recognized a long-press on a tableView - State Possible, ignored" );
			break;
		case UIGestureRecognizerStateBegan:
			//DLog( @"Recognized a long-hold on a tableView" );
			//DLog( @"- State Began at row %d in section %d", indexPathOfLocation.row, indexPathOfLocation.section );
			[self prepareForMoveOfRowAtPoint: currentLocation];
			break;
		case UIGestureRecognizerStateChanged:
			//DLog( @"Recognized a long-hold on a tableView" );
			//DLog( @"- State Changed" );
			[self movingRowIsAtPoint: currentLocation];
			break;
		case UIGestureRecognizerStateEnded:
			//DLog( @"Recognized a long-hold on a tableView" );
			//DLog( @"- State Ended/Recognized at row %d in section %d", indexPathOfLocation.row, indexPathOfLocation.section );
			[self finishMovingRowToPoint: currentLocation];
			break;
		case UIGestureRecognizerStateCancelled:
			//DLog( @"Recognized a long-hold on a tableView" );
			//DLog( @"- State Cancelled" );
			[self cancelMovingRowAtPoint: currentLocation];
			break;
		case UIGestureRecognizerStateFailed:
			DLog( @"Recognized a long-press on a tableView - State Failed, ignored" );
			break;
	}
}
- (void) prepareForMoveOfRowAtPoint: (CGPoint) point {
	DLog( @"Gesture for row reordering recognized for touch at {%g,%g}", point.x, point.y );
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
		   [UIView animateWithDuration: 0.2 animations: ^{
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
		   DLog( @"- - But it is not in a row or the table view data source says this row cannot be moved" );
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
	
        // adjust rect for content inset as we will use it below for calculating scroll zones
        CGRect rect = self.bounds;
        rect.size.height -= self.contentInset.top;
	
	// Figure out if we should scroll and which direction
	// The scroll zone is the proximity to the top or bottom of the screen
	// that the top or bottom of the snap shot row needs to be in to trigger scrolling
	CGFloat scrollZoneHeight = 6;
        CGFloat topScrollBeginning = self.contentOffset.y + self.contentInset.top + scrollZoneHeight;
        CGFloat bottomScrollBeginning = self.contentOffset.y + self.contentInset.top - self.contentInset.bottom + rect.size.height - scrollZoneHeight;
	//DLog( @"=== The boundaries of the scroll regions are at %g and %g", topScrollBeginning, bottomScrollBeginning );
        // We're in the bottom scroll zone
        if( CGRectGetMaxY(self.snapShotOfCellBeingMoved.frame) >= bottomScrollBeginning &&
	    CGRectGetMaxY(self.bounds) < self.contentSize.height - self.contentInset.bottom ) {
		self.reorderAutoScrollRate = (CGRectGetMaxY(self.snapShotOfCellBeingMoved.frame) - bottomScrollBeginning) / (scrollZoneHeight + self.snapShotOfCellBeingMoved.bounds.size.height / 2);
	// We're in the top scroll zone and the content offset is greater than zero (can be reduced)
        } else if( CGRectGetMinY(self.snapShotOfCellBeingMoved.frame) <= topScrollBeginning &&
		   self.contentOffset.y > -self.contentInset.top ) {
		self.reorderAutoScrollRate = (CGRectGetMinY(self.snapShotOfCellBeingMoved.frame) - topScrollBeginning) / (scrollZoneHeight + self.snapShotOfCellBeingMoved.bounds.size.height / 2);
	// We are not in a scroll zone, make sure autoscolling is off.
        } else {
		self.reorderAutoScrollRate = 0.0;
		// Stop the autoscroll timer if needed
 		if( self.reorderAutoScrollTimer ) {
			[self.reorderAutoScrollTimer invalidate];
			self.reorderAutoScrollTimer = nil;
		}
		// Check the position of the snap shot row compared to the tableview
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
	CGRect whereWeWere = [self rectForRowAtIndexPath: self.toIndexPathForRowBeingMoved];
	CGRect whereWeAre = self.snapShotOfCellBeingMoved.frame;
	CGFloat centerX = self.snapShotOfCellBeingMoved.center.x;
	// If where we are is less than where we were, we are moving the row up
	if( CGRectGetMinY(whereWeAre) < CGRectGetMinY(whereWeWere) ) {
		NSIndexPath *rowUnderTopEdge = [self indexPathForRowAtPoint: CGPointMake( centerX,  CGRectGetMinY(whereWeAre))];
		// OK, this says there is a row under the top edge but sometimes
		// it lies and is really in a gap...
		if( rowUnderTopEdge ) {
			DLog( @"++++ The top edge is in row %ld of section %ld", (long) rowUnderTopEdge.row, (long) rowUnderTopEdge.section );
			CGRect rectForRowUnderTopEdge = [self rectForRowAtIndexPath: rowUnderTopEdge];
			DLog( @"     Top edge is at %g, row it is over goes from %g to %g", CGRectGetMinY(whereWeAre), CGRectGetMinY(rectForRowUnderTopEdge), CGRectGetMaxY(rectForRowUnderTopEdge) );
			if( CGRectGetMinY(whereWeAre) > CGRectGetMaxY(rectForRowUnderTopEdge) ) {
				DLog( @"     - We are actually still below that row" );
				// Maybe we are into another row and not in a gap?
				rowUnderTopEdge = nil;
			} else if( CGRectGetMinY(whereWeAre) < CGRectGetMinY(rectForRowUnderTopEdge) ) {
				DLog( @"     - We are actually aleady above that row" );
				// Maybe we are into another row and not in a gap?
				rowUnderTopEdge = nil;
			}
		}
		// The snap shot really is over a cell... see if we should move
		if( rowUnderTopEdge ) {
			// Adjust the destination based on the delegate method
			if( [self.delegate respondsToSelector: @selector(tableView:targetIndexPathForMoveFromRowAtIndexPath:toProposedIndexPath:)] ) {
				rowUnderTopEdge = [self.delegate tableView: self targetIndexPathForMoveFromRowAtIndexPath: self.fromIndexPathOfRowBeingMoved toProposedIndexPath: rowUnderTopEdge];
			}
			// Make sure the destination row is different from the source
			if( [self.toIndexPathForRowBeingMoved compare: rowUnderTopEdge] != NSOrderedSame ) {
				CGRect whereWeMightGo = [self rectForRowAtIndexPath: rowUnderTopEdge];
				if( CGRectGetMinY(whereWeAre) <= CGRectGetMidY(whereWeMightGo) ) {
					[self movePlaceHolderRowFromIndexPath: self.toIndexPathForRowBeingMoved toIndexPath: rowUnderTopEdge];
				}
			}
		// The snap shot is not over a cell, see if we are at the very top or in a gap
		} else {
			// We may be above the first row of the first section...
			CGRect firstHeaderRect = [self rectForHeaderInSection: 0];
			if( CGRectGetMinY(whereWeAre) <= CGRectGetMaxY(firstHeaderRect) ) {
				DLog( @"++++ The top edge is in first section's header" );
				rowUnderTopEdge = [NSIndexPath indexPathForRow: 0 inSection: 0];
				// Adjust the destination based on the delegate method
				if( [self.delegate respondsToSelector: @selector(tableView:targetIndexPathForMoveFromRowAtIndexPath:toProposedIndexPath:)] ) {
					rowUnderTopEdge = [self.delegate tableView: self targetIndexPathForMoveFromRowAtIndexPath: self.fromIndexPathOfRowBeingMoved toProposedIndexPath: rowUnderTopEdge];
				}
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
				DLog( @"++++ The sections on the screen go from %ld to %ld", (long) topSection, (long) bottomSection );
				for( NSInteger section = topSection; section <= bottomSection; ++section ) {
					CGRect sectionHeaderRect = [self rectForHeaderInSection: section];
					CGRect sectionFooterRect = [self rectForFooterInSection: section];
					DLog( @"     Section %ld header: %@, footer: %@", (long) section, NSStringFromCGRect(sectionHeaderRect), NSStringFromCGRect(sectionFooterRect) );
					if( CGRectGetMinY(whereWeAre)  > CGRectGetMinY(sectionHeaderRect) &&
					    CGRectGetMinY(whereWeAre) <= CGRectGetMaxY(sectionHeaderRect) ) {
						DLog( @"     - We are in the header of section %ld (%g <- %g -> %g)", (long) section, CGRectGetMinY(sectionHeaderRect), CGRectGetMinY(whereWeAre), CGRectGetMaxY(sectionHeaderRect) );
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
						DLog( @"     - We are in the footer of section %ld (%g <- %g -> %g)", (long) section, CGRectGetMinY(sectionFooterRect), CGRectGetMinY(whereWeAre), CGRectGetMaxY(sectionFooterRect) );
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
					DLog( @"---- Do the move to the last row of section %ld!", (long) destinationSection );
					NSInteger destinationRow = [self numberOfRowsInSection: destinationSection];
					rowUnderTopEdge = [NSIndexPath indexPathForRow: destinationRow inSection: destinationSection];
					// Adjust the destination based on the delegate method
					if( [self.delegate respondsToSelector: @selector(tableView:targetIndexPathForMoveFromRowAtIndexPath:toProposedIndexPath:)] ) {
						rowUnderTopEdge = [self.delegate tableView: self targetIndexPathForMoveFromRowAtIndexPath: self.fromIndexPathOfRowBeingMoved toProposedIndexPath: rowUnderTopEdge];
					}
					// Make sure the destination row is different from the source row
					if( [self.toIndexPathForRowBeingMoved compare: rowUnderTopEdge] != NSOrderedSame ) {
						[self movePlaceHolderRowFromIndexPath: self.toIndexPathForRowBeingMoved toIndexPath: rowUnderTopEdge];
					}
				} else {
					DLog( @"---- No move yet, not to the middle of the gap" );
				}
			}
		}
	// If where we are is greater than where we were, we are moving the row down
	} else if( CGRectGetMaxY(whereWeAre) > CGRectGetMaxY(whereWeWere) ) {
		NSIndexPath *rowUnderBottomEdge = [self indexPathForRowAtPoint: CGPointMake( centerX,  CGRectGetMaxY(whereWeAre))];
		// OK, this says there is a row under the bottom edge but sometimes
		// it lies and is really in a gap...
		if( rowUnderBottomEdge ) {
			DLog( @"++++ The bottom edge is in row %ld of section %ld", (long) rowUnderBottomEdge.row, (long) rowUnderBottomEdge.section );
			CGRect rectForRowUnderBottomEdge = [self rectForRowAtIndexPath: rowUnderBottomEdge];
			DLog( @"     Bottom edge is at %g, row it is over goes from %g to %g", CGRectGetMaxY(whereWeAre), CGRectGetMinY(rectForRowUnderBottomEdge), CGRectGetMaxY(rectForRowUnderBottomEdge) );
			if( CGRectGetMaxY(whereWeAre) > CGRectGetMaxY(rectForRowUnderBottomEdge) ) {
				DLog( @"     - We are actually already below that row" );
				// Maybe we are into another row and not in a gap?
				rowUnderBottomEdge = nil;
			}
			if( CGRectGetMaxY(whereWeAre) < CGRectGetMinY(rectForRowUnderBottomEdge) ) {
				DLog( @"     - We are actually still above that row" );
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
				DLog( @"++++ The bottom edge is in last section's footer" );
				rowUnderBottomEdge = [NSIndexPath indexPathForRow: [self numberOfRowsInSection: lastSection] - 1 inSection: lastSection];
				// Adjust the destination based on the delegate method
				if( [self.delegate respondsToSelector: @selector(tableView:targetIndexPathForMoveFromRowAtIndexPath:toProposedIndexPath:)] ) {
					rowUnderBottomEdge = [self.delegate tableView: self targetIndexPathForMoveFromRowAtIndexPath: self.fromIndexPathOfRowBeingMoved toProposedIndexPath: rowUnderBottomEdge];
				}
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
				DLog( @"++++ The sections on the screen go from %ld to %ld", (long) topSection, (long) bottomSection );
				for( NSInteger section = topSection; section <= bottomSection; ++section ) {
					CGRect sectionHeaderRect = [self rectForHeaderInSection: section];
					CGRect sectionFooterRect = [self rectForFooterInSection: section];
					DLog( @"     Section %ld header: %@, footer: %@", (long) section, NSStringFromCGRect(sectionHeaderRect), NSStringFromCGRect(sectionFooterRect) );
					// See if we are in the header of this section...
					if( CGRectGetMaxY(whereWeAre)  > CGRectGetMinY(sectionHeaderRect) &&
					    CGRectGetMaxY(whereWeAre) <= CGRectGetMaxY(sectionHeaderRect) ) {
						DLog( @"     - We are in the header of section %ld (%g <- %g -> %g)", (long) section, CGRectGetMinY(sectionHeaderRect), CGRectGetMinY(whereWeAre), CGRectGetMaxY(sectionHeaderRect) );
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
						DLog( @"     - We are in the footer of section %ld (%g <- %g -> %g)", (long) section, CGRectGetMinY(sectionFooterRect), CGRectGetMinY(whereWeAre), CGRectGetMaxY(sectionFooterRect) );
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
					DLog( @"---- Do the move to the first row of section %ld!", (long) destinationSection );
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
					DLog( @"---- No move yet, not to the middle of the gap" );
				}
			}
		}
	}
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
	UITableViewRowAnimation delAnimation = UITableViewRowAnimationAutomatic;
	UITableViewRowAnimation insAnimation = UITableViewRowAnimationAutomatic;
	//if( [toIndexPath isAboveRowAtIndexPath: fromIndexPath] ) {
	//	DLog( @"---- moving up animations." );
	//	delAnimation = UITableViewRowAnimationFade;
	//	insAnimation = UITableViewRowAnimationNone;
	//} else {
	//	DLog( @"---- moving down animations." );
	//	delAnimation = UITableViewRowAnimationFade;
	//	insAnimation = UITableViewRowAnimationNone;
	//}
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
		DLog( @"Moving cancelled, reseting to original state." );
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
		DLog( @"Moving cancelled but calling finish." );
		[self finishMovingRowToPoint: point];
	}
}

- (UIView *) snapShotViewOfCellAtIndexPath: (NSIndexPath *) indexPath {
	if( [self.delegate respondsToSelector: @selector(tableView:snapShotViewOfCellAtIndexPath:)] ) {
		DLog( @"Getting snapshot view of cell at row %ld in section %ld from table view delegate", (long) indexPath.row, (long) indexPath.section );
		return [(id) self.delegate tableView: self snapShotViewOfCellAtIndexPath: indexPath];
	} else {
		DLog( @"Generating snapshot view of cell at row %ld in section %ld", (long) indexPath.row, (long) indexPath.section );
#if 1
	UITableViewCell *touchedCell = [self cellForRowAtIndexPath: indexPath];
	touchedCell.highlighted = NO;
	touchedCell.selected = NO;
	
	// snapshotViewAfterScreenUpdates: is an iOS 7 introduced method!
    // In iOS 8 I get the error:
    //     Snapshotting a view that has not been rendered results in an empty snapshot.
    //     Ensure your view has been rendered at least once before snapshotting or snapshot after screen updates.
    // Even though I have "yes" for AfterScreenUpdates... I guess I can throw it back to the old way for iOS 8 as a work-around!
	UIView *snapShot;
	if( floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1 &&
       [touchedCell respondsToSelector: @selector(snapshotViewAfterScreenUpdates:)] ) {
		snapShot = [touchedCell snapshotViewAfterScreenUpdates: YES];
        // Maybe I should check if the snapShot is nil and fall back to some alternate method?
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
#  if 0	// Too gray....
		snapShot.alpha = 0.70;
		snapShot.layer.shadowOpacity = 1.0;
		snapShot.layer.shadowRadius = 4.0;
		snapShot.layer.shadowOffset = CGSizeMake( 0, 1.5 );
		snapShot.layer.shadowPath = [[UIBezierPath bezierPathWithRect: snapShot.layer.bounds] CGPath];
#  elif 1	// Doing the rasterize gets the gray out...
		snapShot.alpha = 0.70;
		snapShot.layer.shadowOpacity = 1.0;
		snapShot.layer.shadowRadius = 4.0;
		snapShot.layer.shadowOffset = CGSizeMake( 0, 1.5 );
		// Looks better without the shadows path
		//snapShot.layer.shadowPath = [[UIBezierPath bezierPathWithRect: snapShot.layer.bounds] CGPath];
		
		snapShot.layer.rasterizationScale = [[UIScreen mainScreen] scale];
		snapShot.layer.shouldRasterize = YES;
		//
#  elif 0	// Also too gray...
		// add drop shadow to image and lower opacity
		snapShot.layer.masksToBounds = NO;
		snapShot.layer.opacity = 0.6;
		snapShot.layer.shadowOpacity = 0.7;
		snapShot.layer.shadowRadius = 3.0;
		snapShot.layer.shadowColor = [[UIColor blackColor] CGColor];
		snapShot.layer.shadowOffset = CGSizeMake( 0, 1 );
#  else	// Shadows are two horizontal lines...
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
#  endif
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
	CGPoint currentOffset = self.contentOffset;
	CGPoint newOffset = CGPointMake( currentOffset.x, currentOffset.y + self.reorderAutoScrollRate * MAX_SCROLL_RATE );
	DLog( @"AutoScroll Timer Fired, changing content offset from %g to %g, scrollRate is %g", currentOffset.y, newOffset.y, self.reorderAutoScrollRate );
	
	if( newOffset.y < -self.contentInset.top ) {
		newOffset.y = -self.contentInset.top;
		DLog( @"   ~~ Oops, it was < -contentInset.top (%g), so changed to %g", -self.contentInset.top, newOffset.y );
		// We hit the top, don't need to scroll anymore, so invalidate the timer.
		[self.reorderAutoScrollTimer invalidate];
		self.reorderAutoScrollTimer = nil;
	} else if( self.contentSize.height + self.contentInset.bottom < self.frame.size.height ) {
		newOffset = currentOffset;
		DLog( @"   ~~ Oops, contentSize.height (%g) + contentInset.bottom (%g) < frame.size.height (%g) so reset to %g", self.contentSize.height, self.contentInset.bottom, self.frame.size.height, newOffset.y );
	} else if( newOffset.y > (self.contentSize.height + self.contentInset.bottom - self.frame.size.height) ) {
		newOffset.y = (self.contentSize.height + self.contentInset.bottom - self.frame.size.height);
		DLog( @"   ~~ Oops, it was > contentSize.height (%g) + contentInset.bottom (%g) - frame.size.height (%g), so changed to %g", self.contentSize.height, self.contentInset.bottom, self.frame.size.height, newOffset.y );
		// We hit the bottom, don't need to scroll anymore, so invalidate the timer.
		[self.reorderAutoScrollTimer invalidate];
		self.reorderAutoScrollTimer = nil;
	}
	// Set the content offset to the bounds checked value. Even though it
	// does not seem to be in the documentation, contentOffset seems to get
	// rounded to an integer number of pixels (so on a non-retina display
	// gets rounded to a whole number, on a retina display gets rounded to
	// the 0.5). So rather than using 'netOffset' to calculate move distance
	// I will pull it from the contentOffset after setting it.
	self.contentOffset = newOffset;
	DLog( @"~~ Set contentOffset to %g and it is %g", newOffset.y, self.contentOffset.y );
	CGFloat moveDistance = self.contentOffset.y - currentOffset.y;
	if( moveDistance != 0.0 ) {
		CGFloat newCenterY = self.snapShotOfCellBeingMoved.center.y + moveDistance;
		if( newCenterY < self.contentOffset.y + self.contentInset.top )
			newCenterY = self.contentOffset.y + self.contentInset.top;
		if( newCenterY > CGRectGetMaxY(self.bounds) - self.contentInset.bottom )
			newCenterY = CGRectGetMaxY(self.bounds) - self.contentInset.bottom;
		self.snapShotOfCellBeingMoved.center = CGPointMake( self.snapShotOfCellBeingMoved.center.x, newCenterY );
		[self movePlaceHolderRowIfNeeded];
	}
}

#pragma mark - Public methods for interfacing with the reordering methods
- (NSIndexPath *) dataSourceIndexPathFromVisibleIndexPath: (NSIndexPath *) indexPath {
	// Both the to and from locations should be set if we are in a move
	// or either the source or the destination need to be in the section
	// for any of its indeces to have been affected.
	if( !self.toIndexPathForRowBeingMoved || !self.fromIndexPathOfRowBeingMoved ||
	   (indexPath.section != self.toIndexPathForRowBeingMoved.section &&
	    indexPath.section != self.fromIndexPathOfRowBeingMoved.section) ) {
		   //DLog( @"No index path translation needed, not in a move or in a section without the to or from rows" );
		   return indexPath;
	   }
	// So both the toIndex and fromIndex are defined and the indexPath is in one of them
	// If indexPath == toMoveLocation, the it gets the fromMoveIndex
	if( indexPath.section == self.toIndexPathForRowBeingMoved.section &&
	    indexPath.row     == self.toIndexPathForRowBeingMoved.row ) {
		//DLog( @"In a move and a request for the destination cell, so return the index path of the original position" );
		return self.fromIndexPathOfRowBeingMoved;
	}
	if( self.fromIndexPathOfRowBeingMoved.section == self.toIndexPathForRowBeingMoved.section ) {
		//DLog( @"In a move and both the source and destination rows are in the same section" );
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
	//DLog( @"Entering %s", __func__ );
	//DLog( @"- The tableview has %d gesture recognizers", self.gestureRecognizers.count );
	//DLog( @"  They are:\n  -- %@", [self.gestureRecognizers componentsJoinedByString: @"\n  -- "] );
	UILongPressGestureRecognizer *g = objc_getAssociatedObject( self, rowReorderGestureRecognizerKey );
	if( ![g isEqual: rowReorderGestureRecognizer] ) {
		if( rowReorderGestureRecognizer ) {
			objc_setAssociatedObject( self, rowReorderGestureRecognizerKey, rowReorderGestureRecognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
			[self addGestureRecognizer: rowReorderGestureRecognizer];
			//DLog( @"-- Set the gesture recognizer and added it to the tableView" );
		} else if( g && !self.allowsLongPressToReorder && !self.allowsLongPressToReorderDuringEditing ) {
			objc_setAssociatedObject( self, rowReorderGestureRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
			[self removeGestureRecognizer: g];
			//DLog( @"-- Set the gesture recognizer to nil and removed it from the tableView" );
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

#pragma mark - Configuration validation method
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
			DLog( @"Before the faked move, the cell at row %ld in section %ld has a height of %g and row %ld in section %ld has a height of %g", (long) indexPathForH0.row, (long) indexPathForH0.section, h0, (long) indexPathForH1.row, (long) indexPathForH1.section, h1 );
			self.fromIndexPathOfRowBeingMoved = indexPathForH0;
			self.toIndexPathForRowBeingMoved = indexPathForH1;
			NSIndexPath *newIndexPathForH1;
			if( indexPathForH0.section != indexPathForH1.section ) {
				newIndexPathForH1 = [NSIndexPath indexPathForRow: indexPathForH1.row + 1 inSection: indexPathForH1.section];
			} else {
				newIndexPathForH1 = [NSIndexPath indexPathForRow: indexPathForH1.row - 1 inSection: indexPathForH1.section];
			}
			CGFloat h0X = [self.delegate tableView: self heightForRowAtIndexPath: indexPathForH1];
			CGFloat h1X = [self.delegate tableView: self heightForRowAtIndexPath: newIndexPathForH1];
			DLog( @"With row swap the cell at row %ld in section %ld has a height of %g and row %ld in section %ld has a height of %g", (long) indexPathForH1.row, (long) indexPathForH1.section, h0X, (long) newIndexPathForH1.row, (long) newIndexPathForH1.section, h1X );
			if( h0 != h0X || h1 != h1X ) {
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
		} else {
			DLog( @"No cells of different heights found." );
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
	DLog( @"Entering %s", __func__ );
	BOOL shouldBegin = NO;
	UIView	*viewForGesture = gesture.view;
	if( ![viewForGesture isKindOfClass: [UITableView class]] ) {
		DLog( @"- **** The guesture is not attached to a UITableView" );
	} else {
		UITableView *movingInTableView = (UITableView *) viewForGesture;
		CGPoint currentLocation = [gesture locationInView: movingInTableView];
		NSIndexPath *indexPathOfLocation = [movingInTableView indexPathForRowAtPoint: currentLocation];

		if( indexPathOfLocation.length == 2 &&
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
			DLog( @"- everything is set and the gesture should begin" );
		else	DLog( @"- the gesture should not be begin" );
	}
	return shouldBegin;
}

@end

//------------------------------------------------------------------------------
#pragma mark - Implementation for the little convenience extensions to NSIndexPath
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
