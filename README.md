# UITableView+Reorder

This provides easy row reordering with a long press gesture for any UITableView without entering edit mode. It is very easy to use since everything is encapsulated in a category (like Wenting Liu did). The difference between this implementation and his is that no modifications are made to the data source until the use stops dragging the row. This is how the built-in reorder functionality works, in fact, an effort was made to make this category work as closely as possible to the built-in functionality.

This did introduce a little additional complexity in its use. This complexity is in three areas:

1. If the tableview has more than one section it is possible that the tableview will have a different number of rows in a section than the data source says are in the section. This occurs when a row has been dragged from one section to another section. To account for this a helper method is provided to correct the count. Calling `- (NSInteger) adjustedValueForReorderingOfRowCount: (NSInteger) rowCount forSection: (NSInteger) section` will result in the correct value being returned all the time.
2. While a row is being dragged up or down the table there is a disconnect between where the data for that row exists in the data source and where that row is on the screen. In order to deal with this another helper method is provided that translates the index path for the visilbe location on the screen to the index path in the data source: `- (NSIndexPath *) dataSourceIndexPathFromVisibleIndexPath: (NSIndexPath *) indexPath`. This should be used in all tableview delegate or datasource methods that have an `NSIndexPath` argument that is used to get data from the data source.
3. There is an empty place left in the tableview for the row that is being dragged. It is the responsibility of the tableview's data source to provide this cell instead of the normal cell. A helper method is provided so `- (UITableViewCell *) tableView: (UITableView *) tableView cellForRowAtIndexPath: (NSIndexPath *) indexPath` knows whether to return the real cell or the place holder called `- (BOOL) shouldSubstitutePlaceHolderForCellBeingMovedAtIndexPath: (NSIndexPath *) indexPath`.

Everything else that is done is identical to the configuration needed for having row reordering throught the built-in methodology. This includes:

1. Implement:

````
- (void) tableView: (UITableView *) tableView moveRowAtIndexPath: (NSIndexPath *) fromIndexPath toIndexPath: (NSIndexPath *) toIndexPath;
````

2. Moveable rows must be moveable so if

````
- (BOOL) tableView: (UITableView *) tableView canMoveRowAtIndexPath: (NSIndexPath *) indexPath;
````

is implemented then it must return **YES** for any rows that you want to be able to move.

3. Moveable rows must be editable so if

````
- (BOOL) tableView: (UITableView *) tableView canEditRowAtIndexPath: (NSIndexPath *) indexPath;
````

is implemented then it must return **YES** for any rows that you want to be able to move.


Implementations of this functionality as a subclass (like Ben Vogelzang, Florian Mielke and Daniel Shusta did) prevent it from being used on UITableViews that are already built into other classes.

## Example usage:

````
#import "UITableView+Reorder.h"

self.tableView.allowsLongPressToReorder = YES;
````

That is all it takes to enable it. There is also `self.tableView.allowsLongPressToReorderDuringEditing` in case you want to enable reordering while in edit mode without using the reordering handles provided by iOS.

Or, with more details in context....

````
@implementation myTableViewControllerSubclass

- (void) viewDidLoad {
    self.tableView.allowsLongPressToReorder = YES;
}

- (NSInteger) tableView: (UITableView *) tableView numberOfRowsInSection: (NSInteger) section {
	NSInteger rowCount = [self.tableData[section] count];
	rowCount = [tableView adjustedValueForReorderingOfRowCount: rowCount forSection: section];
	return rowCount;
}

- (UITableViewCell *) tableView: (UITableView *) tableView cellForRowAtIndexPath: (NSIndexPath *) indexPath {
    static NSString *CellIdentifier = @"Cell";
    indexPath = [tableView dataSourceIndexPathFromVisibleIndexPath: indexPath];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifier];

    // Configure the cell...
    if( [tableView shouldSubstitutePlaceHolderForCellBeingMovedAtIndexPath: indexPath] ) {
        cell.textLabel.text = @"";
    } else {
        cell.textLabel.text = [NSString stringWithFormat: @"Data element %@", self.tableData[indexPath.section][indexPath.row]];
    }
    return cell;
}
````

## Details

Any of the UITableViewDelegate or UITableVewDataSource methods that could be called while a row is being dragged up or down the screen needs to be modified because there is a separation between what is on the screen and what is in the data source. To do this there is an instance method added to the UITableView class that will convert the row index visible on the screen to the row index in the datasource. This method is:

````
- (NSIndexPath *) dataSourceIndexPathFromVisibleIndexPath: (NSIndexPath *) indexPath;
````

Any method that is passed an `NSIndexPath` that will be used to access the underlying data model for the table view should be adjusted using this method.

## Acknowledgements

Maybe I just like re-inventing the wheel since there is other code out there to accomplish reordering. I looked at and incorporated parts of all of these other sources:

1. https://github.com/wentingliu/UITableView-LongPressReorder
2. https://github.com/FlorianMielke/FMMoveTableView
3. https://github.com/shusta/ReorderingTableViewController
4. https://github.com/bvogelzang/BVReorderTableView

## License

The MIT License (MIT)

Copyright (c) [2014] [David W. Stockton]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
