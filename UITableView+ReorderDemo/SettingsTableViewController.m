//
//  SettingsTableViewController.m
//  UITableView+Reorder
//
//  Created by David W. Stockton on 3/5/14.
//  Copyright (c) 2014 Syntonicity. All rights reserved.
//

#import "SettingsTableViewController.h"
#import "SettingsObject.h"

@interface SettingsTableViewController ()
@property (weak, nonatomic) IBOutlet UISwitch *longPressReorderSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *longPressReorderDuringEditSwitch;
- (IBAction)longPressReorderSwitchChanged:(UISwitch *)sender;
- (IBAction)longPressReorderDuringEditSwitchChanged:(UISwitch *)sender;
@property (weak, nonatomic) IBOutlet UISwitch *variableRowHeightSwitch;
- (IBAction)variableRowHeightSwitchChanged:(UISwitch *)sender;
@property (weak, nonatomic) IBOutlet UISwitch *fromEvenSectionsSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *fromEvenRowsSwitch;
- (IBAction)fromEvenSectionsSwitchChanged:(UISwitch *)sender;
- (IBAction)fromEvenRowsSwitchChanged:(UISwitch *)sender;
@property (weak, nonatomic) IBOutlet UISwitch *toEvenSectionsSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *toEvenRowsSwitch;
- (IBAction)toEvenSectionsSwitchChanged:(UISwitch *)sender;
- (IBAction)toEvenRowsSwitchChanged:(UISwitch *)sender;

@end

@implementation SettingsTableViewController

- (void) viewWillAppear: (BOOL) animated {
	SettingsObject *mso = [SettingsObject masterSettingsObject];
	self.longPressReorderSwitch.on = mso.allowsLongPressToReorder;
	self.longPressReorderDuringEditSwitch.on = mso.allowsLongPressToReorderDuringEditing;

	self.variableRowHeightSwitch.on = mso.useVariableRowHeights;

	self.fromEvenSectionsSwitch.on = mso.canOnlyMoveRowsFromEvenNumberedSections;
	self.fromEvenRowsSwitch.on = mso.canOnlyMoveEvenNumberedRows;

	self.toEvenSectionsSwitch.on = mso.canOnlyMoveToEvenNumberedSections;
	self.toEvenRowsSwitch.on = mso.canOnlyMoveToEvenNumberedRows;
    [super viewWillAppear: animated];
}

- (IBAction)longPressReorderSwitchChanged:(UISwitch *)sender {
	SettingsObject *mso = [SettingsObject masterSettingsObject];
	mso.allowsLongPressToReorder = sender.isOn;
}

- (IBAction)longPressReorderDuringEditSwitchChanged:(UISwitch *)sender {
	SettingsObject *mso = [SettingsObject masterSettingsObject];
	mso.allowsLongPressToReorderDuringEditing = sender.isOn;
}
- (IBAction)variableRowHeightSwitchChanged:(UISwitch *)sender {
	SettingsObject *mso = [SettingsObject masterSettingsObject];
	mso.useVariableRowHeights = sender.isOn;
}

- (IBAction)fromEvenSectionsSwitchChanged:(UISwitch *)sender {
	SettingsObject *mso = [SettingsObject masterSettingsObject];
	mso.canOnlyMoveRowsFromEvenNumberedSections = sender.isOn;
}

- (IBAction)fromEvenRowsSwitchChanged:(UISwitch *)sender {
	SettingsObject *mso = [SettingsObject masterSettingsObject];
	mso.canOnlyMoveEvenNumberedRows = sender.isOn;
}

- (IBAction)toEvenSectionsSwitchChanged:(UISwitch *)sender {
	SettingsObject *mso = [SettingsObject masterSettingsObject];
	mso.canOnlyMoveToEvenNumberedSections = sender.isOn;
}

- (IBAction)toEvenRowsSwitchChanged:(UISwitch *)sender {
	SettingsObject *mso = [SettingsObject masterSettingsObject];
	mso.canOnlyMoveToEvenNumberedRows = sender.isOn;
}
@end
