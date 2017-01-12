//
//  QualityControlWindowController.m
//  XNAT
//
//  Created by Benjamin Yvernault on 17/12/2015.
//
//

#import "XNATFilter.h"
#import "QualityControlWindowController.h"

@implementation QualityControlWindowController

@synthesize currentBrowser;
@synthesize viewer;
@synthesize assessorsData;
@synthesize tableData;
@synthesize tableView;
@synthesize arrayController;

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (id) init:(XNATFilter*) f
{
    self = [super initWithWindowNibName:@"QualityControlWindowController"];
    
    // Init variables
    filter = f;
    [[self window] setDelegate:(id<NSWindowDelegate>)self];
    
    // Current browser window:
    self.currentBrowser = [BrowserController currentBrowser];
    
    // Viewer:
    self.viewer = nil;
    
    // Others
    self.assessorsData = nil;
    self.tableData = nil;
    [self disableQCBox];

    // Warning set color:
    [warning setTextColor: [NSColor grayColor]];
    [warning2 setTextColor: [NSColor grayColor]];
    
    // Check the connection and set project:
    id projects = [[filter xnat] listProjectsOwned];
    if (!projects){
        [utils displayAlert:@"Connection to XNAT failed. Set your logins for XNAT. Go to Plugins -> Database -> XNAT -> connection."];
        [[self window] close];
        return nil;
    }
    
    // Check that the proc:genprocdata datatype from Vanderbilt University is installed on XNAT
    BOOL hasDatatype = [[filter xnat] hasDAXdatatypes];
    NSLog(@"Has Dax datatypes? %hhd", hasDatatype);
    if (![[filter xnat] hasDAXdatatypes]){
        [utils displayAlert:@"DAX datatypes can not be found on your XNAT instance. You can't do Quality Control. This option is reserved for data stored using proc:genProcData.\n\nSee https://github.com/VUIIS/dax/wiki."];
        [[self window] close];
        return nil;
    }
    
    [xnatProject addItemsWithTitles: projects];
    [xnatProject setEnabled:true];
    
    return self;
}

- (void) dealloc
{
    if(self.assessorsData)
        [self.assessorsData release];
    self.assessorsData = nil;
    if(self.tableData)
        [self.tableData release];
    self.tableData = nil;
    [currentBrowser release];
    [viewer release];
    viewer = nil;
    currentBrowser = nil;
    [super dealloc];
}

/* Methods */
- (void) populateTable
{
    // Populate the array Controller that is linked to the tableView
    for(NSDictionary* dico in self.tableData)
        [arrayController addObject:@{@"label": [dico objectForKey:@"label"],
                                     @"jstatus":[dico objectForKey:@"proc:genprocdata/procstatus"],
                                     @"qstatus":[dico objectForKey:@"proc:genprocdata/validation/status"],
                                     @"hasresource":[dico objectForKey:@"resource"]}];
    
    [tableView reloadData];
}

- (void) disableQCBox
{
    //Disable all buttons from the QC Box:
    [utils clearButtons:@[submit, method, notes]];
    [qcStatus setEnabled:false];
    [qcStatus selectItemAtIndex:0];
}

- (void) enableQCBox
{
    //Enable all buttons from the QC Box:
    [qcStatus setEnabled:true];
    [method setEnabled:true];
    [notes setEnabled:true];
    [submit setEnabled:true];
}

- (void) clearTable
{
    // Clear the TableView:
    [arrayController setContent:nil];
    [tableView reloadData];
    [utils clearButtons:@[selectAll]];
}

- (void) qualityControlAssessors:(NSArray*) xnatObjects
{
    @autoreleasepool {
        for(NSDictionary* xnatDict in xnatObjects)
        {
            @autoreleasepool {
                [[filter xnat] editQCStatus:[xnatDict objectForKey:@"label"]
                                 withStatus:[[qcStatus selectedCell] title]
                                usingMethod:[method stringValue]
                                  withNotes:[notes stringValue]];
            }
        }
        [[self window] setOrderedIndex:0];
        [utils displayMessage:@"Status / Description / Notes submitted for all the processes to XNAT."];
    }
}

- (void) loadROI:(NSString*) roiFile onSeries:(DicomSeries*) series withName:(NSString*) roiName
{
    roiName = [utils getSubstring:[roiName stringByDeletingPathExtension] betweenString:@"_" andString:nil];
    @autoreleasepool {
        BOOL ROILoaded = false;
        while(!ROILoaded)
        {
            NSMutableArray* seriesImages = [[[NSMutableArray alloc] initWithArray:[series sortedImages]] autorelease];
            NSMutableArray* pixList = [[[NSMutableArray alloc] init] autorelease];
            for(DicomImage* image in seriesImages)
                [pixList addObject:[DCMPix dcmPixWithImageObj:image]];
            // Load Series
            [self.viewer replaceSeriesWith:pixList :seriesImages :[[NSData alloc] init]];
            // Load file
            [self.viewer roiLoadFromSeries: roiFile];
            // load changes
            [self.viewer changeImageData:pixList :seriesImages :[[NSData alloc] init] :NO];
            // Check that the file has been loaded:
            NSDictionary* roiSeries = [utils extractROIsNamedFromSeries:series];
            NSString* roiDictKey = roiName;
            if ([roiName isEqualToString:@"AlL"] && roiSeries)
                ROILoaded = true;
            else{
                // Get the key for the roi Name we are uploading in case there is a space:
                for(id key in roiSeries){
                    // If space in the roi name, change it by _
                    if([[key stringByReplacingOccurrencesOfString:@" " withString:@"-"] isEqualToString:roiName])
                        roiDictKey = key;
                }
                if([roiSeries valueForKey:roiDictKey] != nil) // a ROI was uploaded
                    ROILoaded = true;
            }
        }
        [utils removeROIFile:roiFile];
    }
}

- (BOOL) downloadAssessor:(NSString*) assessorLabel forResource:(NSString*) resource
{
    @autoreleasepool {
        NSDictionary* xnatInfo = [[filter xnat] extractInfoFromAssessor:assessorLabel];
        NSString* comment = [NSString stringWithFormat:@"project:%@;subject:%@;session:%@;assessor:%@",
                             [xnatInfo valueForKey:@"project"], [xnatInfo valueForKey:@"subject"],
                             [xnatInfo valueForKey:@"session"], assessorLabel];
        NSArray* filesPath = [[filter xnat] downloadFromAssessor:assessorLabel forResource:resource];
        NSMutableArray* seriesSet = [[[NSMutableArray alloc] init] autorelease];
        if ([filesPath count] > 0) {
            // Add the files to the database:
            [[filter xnatDatabase] addFilesAtPaths:filesPath];
            for (NSString* file in filesPath)
            {
                [self.currentBrowser findAndSelectFile:file image:nil shouldExpand:YES];
                DicomSeries* series = [[self.currentBrowser databaseSelection] objectAtIndex:0];
                NSString* strId = [series.id stringValue];
                // If it's a new series, set the comment and download ROI.
                // It's to avoid repeting this action if several files for one serie
                if (![seriesSet containsObject:strId])
                {
                    [series setValue:comment forKey:@"comment2"];
                    
                    // ROI:
                    NSString* roiName = [RoiFilename stringValue];
                    if(roiName)
                    {
                        // Getting the roiFileName:
                        NSArray* ROIfiles = [[filter xnat] listFilesForAssessor:assessorLabel andResource:@"OsiriX_ROI"];
                        for(id ROIfile in ROIfiles)
                        {
                            // Name specified present and right strId in the file name
                            if ([[ROIfile valueForKey:@"Name"] rangeOfString:roiName].location != NSNotFound &&
                                [[ROIfile valueForKey:@"Name"] rangeOfString:strId].location != NSNotFound) {
                                NSString* roiPath = [[filter xnat] downloadFromAssessor:assessorLabel
                                                                            forResource:@"OsiriX_ROI"
                                                                                forFile:[ROIfile valueForKey:@"Name"]];
                                if([roiPath length] > 0)
                                    [self loadROI:roiPath onSeries:series withName:[ROIfile valueForKey:@"Name"]];
                            }
                        }
                    }

                    [seriesSet addObject:strId];
                }
            }
            return true;
        }else{
            return false;
        }
    }
}

- (void) downloadOsirixData:(NSArray*) xnatObjects
{
    @autoreleasepool {
        // Resource is always DICOM for OsiriX
        NSMutableArray* errorAssessor = [[[NSMutableArray alloc] init] autorelease];
        self.viewer = [[ViewerController alloc] init];
        int count = 1;
        for(NSDictionary* xnatDict in xnatObjects)
        {
            [warning2 setStringValue:[NSString stringWithFormat:@"Downloading processed data %d/%lu...", count, [xnatObjects count]]];
            [warning2 setTextColor: [NSColor orangeColor]];
            [warning2 displayIfNeeded];
            [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
            @autoreleasepool {
                BOOL status = [self downloadAssessor:[xnatDict valueForKey:@"label"] forResource:@"OsiriX"];
                if(status == false)
                    [errorAssessor addObject:xnatDict];
            }
            count += 1;
        }

        if(self.viewer)
            [self.viewer close];
        
        [[self window] setOrderedIndex:0];
        if([errorAssessor count] > 0)
        {
            [warning2 setStringValue:@"Warning: some processed data didn't have an OsiriX resource."];
            [warning2 setTextColor: [NSColor orangeColor]];
            [warning2 displayIfNeeded];
            [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
            NSString* errorString = [utils errorAsString:errorAssessor forType:@"assessor"];
            NSString* message = [NSString stringWithFormat:@"Resource OsiriX for some assessors failed to be downloaded from XNAT:\n %@.\nIt could be that no OsiriX are available for those assessors.", errorString];
            [utils displayAlert:message];
        }
        else
        {
            [warning2 setStringValue:@"Check your database for the data. Ready."];
            [warning2 setTextColor: [NSColor blueColor]];
            [warning2 displayIfNeeded];
            [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
            [utils displayMessage:@"Resources OsiriX for assessors successfully downloaded. You can check the resources on your OsiriX database."];
        }
    }
}

/* BUTTON METHODS */
- (IBAction)fromSelectedProjectGetAllAssessors:(NSPopUpButton *)sender
{
    // Set the warning:
    [warning setStringValue:@"Loading project informations..."];
    [warning setTextColor: [NSColor orangeColor]];
    [warning displayIfNeeded];
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
    // Clear the array Controller
    [arrayController setContent:nil];
    // Clear buttons
    [utils clearButtons:@[xnatSession, xnatSubject, assessorProctype, warning2]];
    // Get project and search for Assessors
    NSString* project = [[xnatProject selectedCell] title];
    if([project isEqualToString:@""])
        return;
    // Get all the assessors from the project and display the subjects / types available
    self.assessorsData = [[filter xnat] listAssessorsForProjectWithResource:project];
    [xnatSubject addItemsWithTitles: [self.assessorsData valueForKey:@"subject_label"]];
    [xnatSubject setEnabled:true];
    [assessorProctype addItemsWithTitles: [self.assessorsData valueForKey:@"proc:genprocdata/proctype"]];
    [assessorProctype setEnabled:true];
    [assessorProcStatus addItemsWithTitles: [self.assessorsData valueForKey:@"proc:genprocdata/procstatus"]];
    [assessorProcStatus setEnabled:true];
    [assessorqcStatus addItemsWithTitles: [self.assessorsData valueForKey:@"proc:genprocdata/validation/status"]];
    [assessorqcStatus setEnabled:true];
    [query setEnabled:true];
    [selectAll setEnabled:false];
    [downloadOsirix setEnabled:false];
    [checkROI setEnabled:false];
    if([selectAll state] == NSOnState)
        [selectAll setState:0];
    // Set the warning:
    [warning setStringValue:@"Ready."];
    [warning setTextColor: [NSColor grayColor]];
    [warning displayIfNeeded];
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
}

- (IBAction)fromSelectedSubjectSetSessions:(NSPopUpButton *)sender
{
    // Clear all pop-up button
    NSArray* arrayButton = @[xnatSession, warning2, assessorProctype, assessorProcStatus, assessorqcStatus];
    [utils clearButtons:arrayButton];
    NSString* subject = [[xnatSubject selectedCell] title];
    if([subject isEqualToString:@"ALL"])
    {
        // Set each filter values
        [assessorProctype addItemsWithTitles: [self.assessorsData valueForKey:@"proc:genprocdata/proctype"]];
        [assessorProctype setEnabled:true];
        [assessorProcStatus addItemsWithTitles: [self.assessorsData valueForKey:@"proc:genprocdata/procstatus"]];
        [assessorProcStatus setEnabled:true];
        [assessorqcStatus addItemsWithTitles: [self.assessorsData valueForKey:@"proc:genprocdata/validation/status"]];
        [assessorqcStatus setEnabled:true];
    }
    else{
        id data = [[filter xnat] listSessionsForProject:[[xnatProject selectedCell] title]
                                             andSubject:subject];
        [utils setXnatInformation:data forLabel:@"label" onLevel:1 fromPopUpButton:xnatSubject onPopUpButton:xnatSession];
        // Filter the types to show only the one available for subject
        NSDictionary* attributes = [[[NSMutableDictionary alloc] init] autorelease];
        [attributes setValue:subject forKey:@"subject_label"];
        // Filter
        id data_types = [utils filterListOfDictionaries:self.assessorsData forAttributes:attributes];
        [utils setXnatInformation:data_types forLabel:@"proc:genprocdata/proctype" onLevel:1
                  fromPopUpButton:xnatSubject onPopUpButton:assessorProctype];
        [utils setXnatInformation:data_types forLabel:@"proc:genprocdata/procstatus" onLevel:1
                  fromPopUpButton:xnatSubject onPopUpButton:assessorProcStatus];
        [utils setXnatInformation:data_types forLabel:@"proc:genprocdata/validation/status" onLevel:1
                  fromPopUpButton:xnatSubject onPopUpButton:assessorqcStatus];
    }
}

- (IBAction)fromSelectedSessionSetFiltersValue:(NSPopUpButton *)sender
{
    // Clear all pop-up button
    NSArray* arrayButton = @[warning2, assessorProctype, assessorProcStatus, assessorqcStatus];
    [utils clearButtons:arrayButton];
    NSString* subject = [[xnatSubject selectedCell] title];
    NSString* session = [[xnatSession selectedCell] title];
    if([session isEqualToString:@"ALL"]){
        // Set the types back to the types for all the sessions for the specific subject
        NSDictionary* attributes = [[[NSMutableDictionary alloc] init] autorelease];
        [attributes setValue:subject forKey:@"subject_label"];
        // Filter
        id data_types = [utils filterListOfDictionaries:self.assessorsData forAttributes:attributes];
        [utils setXnatInformation:data_types forLabel:@"proc:genprocdata/proctype" onLevel:1
                  fromPopUpButton:xnatSubject onPopUpButton:assessorProctype];
        [utils setXnatInformation:data_types forLabel:@"proc:genprocdata/procstatus" onLevel:1
                  fromPopUpButton:xnatSubject onPopUpButton:assessorProcStatus];
        [utils setXnatInformation:data_types forLabel:@"proc:genprocdata/validation/status" onLevel:1
                  fromPopUpButton:xnatSubject onPopUpButton:assessorqcStatus];
    }
    else{
        // Filter the types to show only the one available for subject/session
        NSDictionary* attributes = [[[NSMutableDictionary alloc] init] autorelease];
        [attributes setValue:subject forKey:@"subject_label"];
        [attributes setValue:session forKey:@"label"];
        // Filter
        id data_types = [utils filterListOfDictionaries:self.assessorsData forAttributes:attributes];
        [utils setXnatInformation:data_types forLabel:@"proc:genprocdata/proctype" onLevel:1
                  fromPopUpButton:xnatSubject onPopUpButton:assessorProctype];
        [utils setXnatInformation:data_types forLabel:@"proc:genprocdata/procstatus" onLevel:1
                  fromPopUpButton:xnatSubject onPopUpButton:assessorProcStatus];
        [utils setXnatInformation:data_types forLabel:@"proc:genprocdata/validation/status" onLevel:1
                  fromPopUpButton:xnatSubject onPopUpButton:assessorqcStatus];
    }
}


- (IBAction)queryXnat:(NSButton *)sender
{
    // Clearing the warning
    [warning2 setStringValue:@""];
    [warning2 displayIfNeeded];
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
    [self clearTable];
    // Set the filters if selected
    NSDictionary* attributes = [[[NSMutableDictionary alloc] init] autorelease];
    // Subject
    NSString* subject = [[xnatSubject selectedCell] title];
    if(![subject isEqualToString:@"ALL"])
        [attributes setValue:subject forKey:@"subject_label"];
    // Session
    NSString* session = [[xnatSession selectedCell] title];
    if(![session isEqualToString:@"ALL"])
        [attributes setValue:session forKey:@"xnat:imagesessiondata/label"];
    // Scan Type
    NSString* procType = [[assessorProctype selectedCell] title];
    if(![procType isEqualToString:@"ALL"])
        [attributes setValue:procType forKey:@"proc:genprocdata/proctype"];
    // Scan Type
    NSString* procStatus = [[assessorProcStatus selectedCell] title];
    if(![procStatus isEqualToString:@"ALL"])
        [attributes setValue:procStatus forKey:@"proc:genprocdata/procstatus"];
    // Scan Type
    NSString* qualityStatus = [[assessorqcStatus selectedCell] title];
    if(![qualityStatus isEqualToString:@"ALL"])
        [attributes setValue:qualityStatus forKey:@"proc:genprocdata/validation/status"];
    // Filter
    if([attributes count] > 0)
        self.tableData = [utils filterListOfDictionaries:self.assessorsData forAttributes:attributes];
    else
        self.tableData = self.assessorsData;
    if([self.tableData count] == 0){
        [utils displayAlert:@"The filters you selected didn’t match any processing in your project. Please change the filters."];
    }else{
        [self populateTable];
        [tableView deselectAll:nil];
        [selectAll setEnabled:true];
        [downloadOsirix setEnabled:true];
        [checkROI setEnabled:true];
    }
}

- (IBAction) selectAllProcesses:(id)sender
{
    // Clearing the warning
    [warning2 setStringValue:@""];
    [warning2 displayIfNeeded];
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
    if([selectAll state] == NSOnState)
        [tableView selectAll:nil];
    else
        [tableView deselectAll:nil];
}

- (IBAction) columnChangeSelected:(id)sender
{
    // Clearing the warning
    [warning2 setStringValue:@""];
    [warning2 displayIfNeeded];
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
    NSInteger selectedRow = [tableView selectedRow];
    [self disableQCBox];
    if([selectAll state] == NSOnState)
        [selectAll setState:0];
    if (selectedRow != -1) {
        [self enableQCBox];
        NSArray* arrangedObjects = [arrayController arrangedObjects];
        id assessor = [arrangedObjects objectAtIndex:selectedRow];
        NSPredicate* pre = [NSPredicate predicateWithFormat:@"SELF.%@ == %@", @"label", [assessor valueForKey:@"label"]];
        NSDictionary* rightAssessor = [[self.tableData filteredArrayUsingPredicate:pre] objectAtIndex:0];

        [qcStatus selectItemWithTitle:[rightAssessor valueForKey:@"proc:genprocdata/validation/status"]];
        [notes setStringValue:[rightAssessor valueForKey:@"proc:genprocdata/validation/notes"]];
        [method setStringValue:[rightAssessor valueForKey:@"proc:genprocdata/validation/notes"]];
    }
}

- (IBAction) submitQualityControl:(id)sender
{
    // Edit Warning:
    [warning2 setStringValue:@"Setting the quality status on XNAT..."];
    [warning2 setTextColor: [NSColor orangeColor]];
    [warning2 displayIfNeeded];
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
    // Set status on XNAT for the processed Data:
    NSMutableArray* assessorsList = [[[NSMutableArray alloc] init] autorelease];
    NSIndexSet *selectedItems = [tableView selectedRowIndexes];
    NSArray* arrangedObjects = [arrayController arrangedObjects];
    [selectedItems enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        // Get index if sorted:
        id scan = [arrangedObjects objectAtIndex:idx];
        NSPredicate* pre = [NSPredicate predicateWithFormat:@"SELF.%@ == %@", @"label",
                            [scan valueForKey:@"label"]];
        [assessorsList addObject:[[self.tableData filteredArrayUsingPredicate:pre] objectAtIndex:0]];
    }];
    
    if([assessorsList count] == 0)
        [utils displayAlert:@"Please select assessor(s) to set QC."];
    else if ([[[qcStatus selectedCell] title] isEqualTo:@""])
        [utils displayAlert:@"Please select a status to set."];
    else
    {
        [self qualityControlAssessors:assessorsList];
        [warning2 setStringValue:@"Done."];
        [warning2 setTextColor: [NSColor blueColor]];
        [warning2 displayIfNeeded];
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
        [[self window] close];
    }
}

- (IBAction)downloadDataFromXnat:(NSButton *)sender
{
    // Get list of scans to download from selected list:
    NSMutableArray* assessorsList = [[[NSMutableArray alloc] init] autorelease];
    NSIndexSet *selectedItems = [tableView selectedRowIndexes];
    NSArray* arrangedObjects = [arrayController arrangedObjects];
    [selectedItems enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        // Get index if sorted:
        id assessor = [arrangedObjects objectAtIndex:idx];
        NSPredicate* pre = [NSPredicate predicateWithFormat:@"SELF.%@ == %@", @"label", [assessor valueForKey:@"label"]];
        [assessorsList addObject:[[self.tableData filteredArrayUsingPredicate:pre] objectAtIndex:0]];
    }];
    
    if([assessorsList count] == 0)
        [utils displayAlert:@"Please select assessor(s) to be downloaded."];
    else{
        // Set the warning:
        [warning2 setStringValue:@"Downloading processed data ..."];
        [warning2 setTextColor: [NSColor orangeColor]];
        [warning2 displayIfNeeded];
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
        [self downloadOsirixData:assessorsList];
    }
}

- (IBAction)checkROIFilenameXNAT:(NSButton *)sender
{
    // Get list of scans to download from selected list:
    NSMutableArray* assessorsList = [[[NSMutableArray alloc] init] autorelease];
    NSIndexSet *selectedItems = [tableView selectedRowIndexes];
    NSArray* arrangedObjects = [arrayController arrangedObjects];
    [selectedItems enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        // Get index if sorted:
        id assessor = [arrangedObjects objectAtIndex:idx];
        NSPredicate* pre = [NSPredicate predicateWithFormat:@"SELF.%@ == %@", @"label", [assessor valueForKey:@"label"]];
        [assessorsList addObject:[[self.tableData filteredArrayUsingPredicate:pre] objectAtIndex:0]];
    }];
    
    if([assessorsList count] != 1 )
        [utils displayAlert:@"Please select one process and only one to check the ROI Filename stored on XNAT."];
    else
    {
        NSDictionary* assessor = [assessorsList objectAtIndex:0];
        NSArray* filenames = [[filter xnat] listFilesForAssessor:[assessor valueForKey:@"label"]
                                                     andResource:@"OsiriX_ROI"];
        if([[filenames valueForKey:@"Name"] count] > 0)
        {
            NSString* message = [NSString stringWithFormat:@"The files on XNAT are listed below:\n   - %@",
                                 [[filenames valueForKey:@"Name"] componentsJoinedByString:@"\n   - "]];
            [utils displayMessage:message];
        }
        else
            [utils displayMessage:@"No ROI found for OsiriX on XNAT for the process selected."];
    }
}


@end
