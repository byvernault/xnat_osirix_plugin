//
//  downloadWindowController.m
//  XNAT
//
//  Created by Benjamin Yvernault on 13/10/2015.
//
//

#import "XNATFilter.h"
#import "downloadWindowController.h"
#import "ConnectionWindowController.h"

/* downloadWindowController implementation */
@implementation downloadWindowController

@synthesize currentBrowser;
@synthesize viewer;
@synthesize scansData;
@synthesize tableData;
@synthesize tableView;
@synthesize arrayController;

/* Init Methods */
- (id) init:(XNATFilter*) f
{
    self = [super initWithWindowNibName:@"downloadWindowController"];
    filter = f;
    [[self window] setDelegate:(id<NSWindowDelegate>)self];
    
    //Current browser window:
    self.currentBrowser = [BrowserController currentBrowser];
    
    //Viewer:
    self.viewer = nil;
    
    //Warning set color:
    [warning setTextColor: [NSColor grayColor]];
    [warning2 setTextColor: [NSColor grayColor]];
    
    // Check the connection and set project:
    id projects = [[filter xnat] listProjectsOwned];
    if (!projects){
        [utils displayAlert:@"Connection to XNAT failed. Set your logins for XNAT. Go to Plugins -> Database -> XNAT -> connection."];
        [[self window] close];
        return nil;
    }
    else{
        [xnatProject addItemsWithTitles: projects];
        [xnatProject setEnabled:true];
        return self;
    }
}

- (void) dealloc
{
    if(self.scansData)
        [self.scansData release];
    self.scansData = nil;
    if(self.tableData)
        [self.tableData release];
    self.tableData = nil;
    [super dealloc];
    [currentBrowser release];
    [viewer release];
    viewer = nil;
    currentBrowser = nil;
    [super dealloc];
}

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    return self;
}

- (void)windowDidLoad
{
     // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    [super windowDidLoad];
    [downloadProgress displayIfNeeded];
    [downloadProgress setMinValue:0.0];
    [downloadProgress setMaxValue:100.0];
    [downloadProgress setDoubleValue:0.0];
    [downloadProgress setNeedsDisplay:true];
    [downloadProgress setIndeterminate:false];
    [downloadProgress setUsesThreadedAnimation:true];
}

/* Methods for table*/
- (void) populateTable
{
    // Populate the array Controller that is linked to the tableView
    for(NSDictionary* dico in self.tableData)
        [arrayController addObject:@{@"session": [dico objectForKey:@"label"],
                                     @"id": [dico objectForKey:@"xnat:imagescandata/id"],
                                     @"type":[dico objectForKey:@"xnat:imagescandata/type"],
                                     @"sd":[dico objectForKey:@"xnat:imagescandata/series_description"],
                                     @"quality":[dico objectForKey:@"xnat:imagescandata/quality"],
                                     @"resource":[dico objectForKey:@"resource"]}];
    
    [tableView reloadData];
}

-(void) clearTable
{
    // Clear the TableView:
    [arrayController setContent:nil];
    [tableView reloadData];
    [utils clearButtons:@[selectAll]];
}

/* Methods */
- (void) loadROI:(NSString*) roiFile onSeries:(DicomSeries*) series withName:(NSString*) roiName
{
    NSLog(@"roi name: %@", roiName);
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


- (BOOL) downloadScan:(NSString*) project forSubject:(NSString*) subject forSession:(NSString*) session forScan:(NSString*) scan
          forResource:(NSString*) resource
{
    @autoreleasepool {
        NSArray* filesPath = [[filter xnat] downloadFromScan:project forSubject:subject forSession:session forScan:scan forResource:resource];
        if ([filesPath count] > 0) {
            // Add the files to the database:
            [[filter xnatDatabase] addFilesAtPaths:filesPath];
            [self.currentBrowser findAndSelectFile:[filesPath objectAtIndex:0] image:nil shouldExpand:YES];
            NSString* comment = [NSString stringWithFormat:@"project:%@;subject:%@;session:%@;scan:%@", project, subject, session, scan];
            DicomSeries* series = [[self.currentBrowser databaseSelection] objectAtIndex:0];
            [series setValue:comment forKey:@"comment2"];
            // ROI:
            NSString* roiName = [RoiFilename stringValue];
            if(roiName)
            {
                // Getting the roiFileName:
                NSArray* ROIfiles = [[filter xnat] listFilesForProject:project andSubject:subject andSession:session andScan:scan andResource:@"OsiriX"];
                for(id ROIfile in ROIfiles)
                {
                    if ([[ROIfile valueForKey:@"Name"] rangeOfString:roiName].location != NSNotFound) {
                         NSString* roiPath = [[filter xnat] downloadFromScan:project
                                                                  forSubject:subject
                                                                  forSession:session
                                                                     forScan:scan
                                                                 forResource:@"OsiriX"
                                                                     forFile:[ROIfile valueForKey:@"Name"]];
                         if([roiPath length] > 0)
                             [self loadROI:roiPath onSeries:series withName:[ROIfile valueForKey:@"Name"]];
                    }
                }
            }
            return true;
        }else{
            return false;
        }
    }
}

- (void) downloadScans:(NSArray*) xnatObjects
{
    @autoreleasepool {
        [downloadProgress startAnimation:nil];
        // Resource is always DICOM for OsiriX
        NSMutableArray* errorScan = [[[NSMutableArray alloc] init] autorelease];
        NSUInteger progressAmount = [xnatObjects count];
        double increment = 100.0/(double)progressAmount;
        self.viewer = [[ViewerController alloc] init];
        for( int i=0; i < progressAmount; i++)
        {
            @autoreleasepool {
                NSDictionary* xnatDict = [xnatObjects objectAtIndex:i];
                BOOL status = [self downloadScan:[xnatDict valueForKey:@"project"]
                                      forSubject:[xnatDict valueForKey:@"subject_label"]
                                      forSession:[xnatDict valueForKey:@"label"]
                                         forScan:[xnatDict valueForKey:@"xnat:imagescandata/id"]
                                     forResource:@"DICOM"];
                if(status == false)
                    [errorScan addObject:xnatDict];
            }
            double progressValue = increment*(double)(i+1);
            [downloadProgress setDoubleValue:progressValue];
            [downloadProgress displayIfNeeded];
            [progressPercent setStringValue:[NSString stringWithFormat:@"%.0f%%",progressValue]];
            [progressPercent displayIfNeeded];
            [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
        }
        if(self.viewer)
            [self.viewer close];
        
        [[self window] setOrderedIndex:0];
        if([errorScan count] > 0)
        {
            NSString* errorString = [utils errorAsString:errorScan forType:@"scan"];
            NSString* message = [NSString stringWithFormat:@"Resource DICOM for some scans failed to be downloaded from XNAT:\n %@.\nIt could be that no DICOM are available for those scans.", errorString];
            [utils displayAlert:message];
        }
        else
            [utils displayMessage:@"Resources DICOM for scans successfully downloaded."];
    }
    [downloadProgress stopAnimation:nil];
}

/* BUTTON METHODS */
- (IBAction)downloadFromXnat:(NSButton *)sender
{
    // Get list of scans to download from selected list:
    NSMutableArray* scansList = [[[NSMutableArray alloc] init] autorelease];
    NSIndexSet *selectedItems = [tableView selectedRowIndexes];
    NSArray* arrangedObjects = [arrayController arrangedObjects];
    [selectedItems enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        // Get index if sorted:
        id scan = [arrangedObjects objectAtIndex:idx];
        NSPredicate* pre = [NSPredicate predicateWithFormat:@"SELF.%@ == %@ AND SELF.%@ == %@", @"label",
                            [scan valueForKey:@"session"], @"xnat:imagescandata/id", [scan valueForKey:@"id"]];
        [scansList addObject:[[self.tableData filteredArrayUsingPredicate:pre] objectAtIndex:0]];
    }];

    if([scansList count] == 0)
        [utils displayAlert:@"Please select scan(s) to be downloaded."];
    else
    {
        [warning setStringValue:@"Please be patient while downloading ..."];
        [warning setTextColor: [NSColor orangeColor]];
        [warning displayIfNeeded];
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
        [self downloadScans:scansList];
        // Set the warning:
        [warning2 setStringValue:@"Done."];
        [warning2 setTextColor: [NSColor blueColor]];
        [warning2 displayIfNeeded];
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
        [[self window] close];
    }
}

- (IBAction)fromSelectedProjectGetAllScans:(NSPopUpButton *)sender
{
    // Set the warning:
    [warning2 setStringValue:@"Loading project informations..."];
    [warning2 setTextColor: [NSColor orangeColor]];
    [warning2 displayIfNeeded];
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
    // Clear the array Controller
    [arrayController setContent:nil];
    // Clear buttons
    [utils clearButtons:@[xnatSession, xnatSubject, scanTypes]];
    // Get project and search for Scans
    NSString* project = [[xnatProject selectedCell] title];
    if([project isEqualToString:@""])
        return;
    // Get all the scans from the project and display the subjects / types available
    self.scansData = [[filter xnat] listScansForProjectWithResource:project];
    [xnatSubject addItemsWithTitles: [self.scansData valueForKey:@"subject_label"]];
    [xnatSubject setEnabled:true];
    [scanTypes addItemsWithTitles: [self.scansData valueForKey:@"xnat:imagescandata/type"]];
    [scanTypes setEnabled:true];
    [query setEnabled:true];
    [selectAll setEnabled:false];
    [checkROI setEnabled:false];
    if([selectAll state] == NSOnState)
        [selectAll setState:0];
    // Set the warning:
    [warning2 setStringValue:@"Ready."];
    [warning2 setTextColor: [NSColor grayColor]];
    [warning2 displayIfNeeded];
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
}

- (IBAction)fromSelectedSubjectSetSessions:(NSPopUpButton *)sender
{
    // Clear all pop-up button
    NSArray* arrayButton = @[xnatSession, scanTypes];
    [utils clearButtons:arrayButton];
    NSString* subject = [[xnatSubject selectedCell] title];
    if([subject isEqualToString:@"ALL"])
    {
        // Set the scan types to all.
        [scanTypes addItemsWithTitles: [self.scansData valueForKey:@"xnat:imagescandata/type"]];
        [scanTypes setEnabled:true];
    }
    else{
        id data = [[filter xnat] listSessionsForProject:[[xnatProject selectedCell] title]
                                             andSubject:subject];
        [utils setXnatInformation:data forLabel:@"label" onLevel:1 fromPopUpButton:xnatSubject onPopUpButton:xnatSession];
        // Filter the types to show only the one available for subject
        NSDictionary* attributes = [[[NSMutableDictionary alloc] init] autorelease];
        [attributes setValue:subject forKey:@"subject_label"];
        // Filter
        id data_types = [utils filterListOfDictionaries:self.scansData forAttributes:attributes];
        [utils setXnatInformation:data_types forLabel:@"xnat:imagescandata/type" onLevel:1
                  fromPopUpButton:xnatSubject onPopUpButton:scanTypes];
    }
}

- (IBAction)fromSelectedSessionSetType:(NSPopUpButton *)sender
{
    // Clear all pop-up button
    NSArray* arrayButton = @[scanTypes];
    [utils clearButtons:arrayButton];
    NSString* subject = [[xnatSubject selectedCell] title];
    NSString* session = [[xnatSession selectedCell] title];
    if([session isEqualToString:@"ALL"]){
        // Set the types back to the types for all the sessions for the specific subject
        NSDictionary* attributes = [[[NSMutableDictionary alloc] init] autorelease];
        [attributes setValue:subject forKey:@"subject_label"];
        // Filter
        id data_types = [utils filterListOfDictionaries:self.scansData forAttributes:attributes];
        [utils setXnatInformation:data_types forLabel:@"xnat:imagescandata/type" onLevel:1
                  fromPopUpButton:xnatSubject onPopUpButton:scanTypes];
    }
    else{
        // Filter the types to show only the one available for subject/session
        NSDictionary* attributes = [[[NSMutableDictionary alloc] init] autorelease];
        [attributes setValue:subject forKey:@"subject_label"];
        [attributes setValue:session forKey:@"label"];
        // Filter
        id data_types = [utils filterListOfDictionaries:self.scansData forAttributes:attributes];
        [utils setXnatInformation:data_types forLabel:@"xnat:imagescandata/type" onLevel:1
                  fromPopUpButton:xnatSession onPopUpButton:scanTypes];
    }
}

- (IBAction)queryXnat:(NSButton *)sender
{
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
        [attributes setValue:session forKey:@"label"];
    // Scan Type
    NSString* scanType = [[scanTypes selectedCell] title];
    if(![scanType isEqualToString:@"ALL"])
        [attributes setValue:scanType forKey:@"xnat:imagescandata/type"];
    // Filter
    if([attributes count] > 0)
        self.tableData = [utils filterListOfDictionaries:self.scansData forAttributes:attributes];
    else
        self.tableData = self.scansData;
    if([self.tableData count] == 0){
        [utils displayAlert:@"The filters you selected didn’t match any scan in your project. Please change the filters."];
    }else{
        [self populateTable];
        [tableView deselectAll:nil];
        [selectAll setEnabled:true];
        [checkROI setEnabled:true];
        if([selectAll state] == NSOnState)
            [selectAll setState:0];
        [downloadButton setEnabled:true];
    }
}

- (IBAction)selectAllScans:(NSButton *)sender
{
    if([selectAll state] == NSOnState)
        [tableView selectAll:nil];
    else
        [tableView deselectAll:nil];
}

- (IBAction)checkROIFilenameXNAT:(NSButton *)sender
{
    // Get list of scans to download from selected list:
    NSMutableArray* scansList = [[[NSMutableArray alloc] init] autorelease];
    NSIndexSet *selectedItems = [tableView selectedRowIndexes];
    NSArray* arrangedObjects = [arrayController arrangedObjects];
    [selectedItems enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        // Get index if sorted:
        id scan = [arrangedObjects objectAtIndex:idx];
        NSPredicate* pre = [NSPredicate predicateWithFormat:@"SELF.%@ == %@ AND SELF.%@ == %@", @"label",
                            [scan valueForKey:@"session"], @"xnat:imagescandata/id", [scan valueForKey:@"id"]];
        [scansList addObject:[[self.tableData filteredArrayUsingPredicate:pre] objectAtIndex:0]];
    }];
    
    if([scansList count] != 1 )
        [utils displayAlert:@"Please select one scan and only one to check the ROI Filename stored on XNAT."];
    else
    {
        NSDictionary* scan = [scansList objectAtIndex:0];
        NSArray* filenames = [[filter xnat] listFilesForProject:[scan valueForKey:@"project"]
                                                     andSubject:[scan valueForKey:@"subject_label"]
                                                     andSession:[scan valueForKey:@"label"]
                                                        andScan:[scan valueForKey:@"xnat:imagescandata/id"]
                                                    andResource:@"OsiriX"];
        if([[filenames valueForKey:@"Name"] count] > 0)
        {
            NSString* message = [NSString stringWithFormat:@"The files on XNAT are listed below:\n   - %@",
                                 [[filenames valueForKey:@"Name"] componentsJoinedByString:@"\n   - "]];
            [utils displayMessage:message];
        }
        else
            [utils displayMessage:@"No ROI found for OsiriX on XNAT for the scan selected."];
    }
}

- (IBAction) columnChangeSelected:(id)sender
{
    if([selectAll state] == NSOnState)
        [selectAll setState:0];
}

@end
