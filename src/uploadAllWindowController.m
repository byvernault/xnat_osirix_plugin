//
//  uploadAllWindowController.m
//  XNAT
//
//  Created by Benjamin Yvernault on 02/11/2015.
//
//

#import "XNATFilter.h"
#import "uploadAllWindowController.h"

@implementation uploadAllWindowController

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
    self = [super initWithWindowNibName:@"uploadAllWindowController"];
    
    // Init variables
    filter = f;
    [[self window] setDelegate:(id<NSWindowDelegate>)self];
    
    // Check the connection and set project:
    id projects = [[filter xnat] listProjects];
    if (!projects){
        [utils displayAlert:@"Connection to XNAT failed. Set your proper logins for XNAT. Go to Plugins -> Database -> XNAT -> connection." ];
        [[self window] close];
        return nil;
    }
    else{
        [warning setStringValue:@"Select a name for ROI file."];
        [warning setTextColor: [NSColor grayColor]];
        [warning displayIfNeeded];
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
        return self;
    }
    
    return self;
}

- (void) dealloc
{
    [super dealloc];
}

/* METHODS */
- (void) uploadFile:(NSString*) roiFile
       onXnatObject:(NSDictionary*) xnatInfo
          overwrite:(BOOL) overwrite
             onScan:(BOOL) scan
{
    if(scan)
        [[filter xnat] uploadFile:roiFile toScan:xnatInfo toResource:@"OsiriX" overwrite:true];
    else
        [[filter xnat] uploadFile:roiFile toAssessor:[xnatInfo valueForKey:@"assessor"] toResource:@"OsiriX_ROI" overwrite:true];

}

- (BOOL) fileExists:(NSString*) roiFile
       onXnatObject:(NSDictionary*) xnatInfo
             onScan:(BOOL) scan
{
    if(scan)
        return [[filter xnat] fileExistsforScan:xnatInfo forResource:@"OsiriX" forFile:[roiFile lastPathComponent]];
    else
        return [[filter xnat] fileExistsforAssessor:[xnatInfo valueForKey:@"assessor"] forResource:@"OsiriX_ROI"
                                            forFile:[roiFile lastPathComponent]];
}

- (void) uploadROIToObj:(NSDictionary*) xnatInfo
                 forROI:(NSArray*) roiList
           withFileName:(NSString*) fileName
              overwrite:(BOOL*) overwrite
                 forAll:(BOOL*) forAll
                 onScan:(BOOL) scan
{
//    NSString* tempDirName = @"";
//    if(scan){
//        tempDirName = [NSString stringWithFormat:@"%@_%@_%@_%@_%@_TMP_UPLOAD", [filter osirixDatabaseName],
//                       [xnatInfo objectForKey:@"project"], [xnatInfo objectForKey:@"session"],
//                       [xnatInfo objectForKey:@"scan"], @"OsiriX"];
//    }else{
//        tempDirName = [NSString stringWithFormat:@"%@_%@_%@_TMP_UPLOAD", [filter osirixDatabaseName],
//                       [xnatInfo objectForKey:@"assessor"], @"OsiriX"];
//    }
//
//    NSString* directory = [NSString stringWithFormat:@"/tmp/%@", tempDirName];
//    [utils createDirectory:directory removeContentIfExists:false];
    NSString* directory = @"/tmp/";
    NSString* filePath = [NSString stringWithFormat:@"%@/%@.rois_series", directory, [fileName stringByDeletingPathExtension]];
    NSString* roiFile = [utils roiSave:roiList inFile:filePath];
    if([roiFile length] > 0){
        if(*overwrite) // overwrite the file
        {
            [self uploadFile:roiFile onXnatObject:xnatInfo overwrite:true onScan:scan];
        }
        else if(*forAll && !*overwrite) //not overwrite for all, so upload without overwrite false
        {
            if(![self fileExists:filePath onXnatObject:xnatInfo onScan:scan])
                [self uploadFile:roiFile onXnatObject:xnatInfo overwrite:false onScan:scan];
        }
        else{
            // if the file exists on the assessor and not overwrite, message to ask user
            if([self fileExists:filePath onXnatObject:xnatInfo onScan:scan])
            {
                NSString* message = @"";
                if (scan)
                    message = [NSString stringWithFormat:@"File %@ already exists for %@ / %@ on XNAT. Do you want to overwrite the file?",
                               [filePath lastPathComponent], [xnatInfo objectForKey:@"session"], [xnatInfo objectForKey:@"scan"]];
                else
                    message = [NSString stringWithFormat:@"File %@ already exists for %@ on XNAT. Do you want to overwrite the file?",
                               [filePath lastPathComponent], [xnatInfo objectForKey:@"assessor"]];
                BOOL overwriteForFile = [utils overwriteAlert:message forAll:forAll];
                if(overwriteForFile)
                    [self uploadFile:roiFile onXnatObject:xnatInfo overwrite:true onScan:scan];
                if(*forAll)
                    *overwrite = overwriteForFile;
            }else
                [self uploadFile:roiFile onXnatObject:xnatInfo overwrite:false onScan:scan];
        }
        [utils removeROIFile:roiFile];
    }
}

/* BUTTON METHODS */
- (IBAction)uploadData:(id)sender
{
    // Access information from selected DICOM:
    NSArray * selectedSeries = [utils getListImageSeries:[[BrowserController currentBrowser] databaseSelection]];
    BOOL overwrite = false;
    BOOL forAll = false;
    BOOL forAllWarning = false;
    BOOL uploaded = false;
    int count = 1;
    for(DicomSeries* series in selectedSeries)
    {
        // XNAT info
        NSDictionary* xnatInfo = [utils readInfoFromComment:[series valueForKey:@"comment2"]];
        if([[filter xnat] objectExistsOnXnat:xnatInfo])
        {
            [warning setStringValue:[NSString stringWithFormat:@"Uploading ROIs for image %d/%lu...", count, [selectedSeries count]]];
            [warning setTextColor: [NSColor orangeColor]];
            [warning displayIfNeeded];
            [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
            // Upload Data : get the files from OsiriX
            NSDictionary* roiList = [NSDictionary new];
            if([oneFile state] == NSOnState)
            {
                NSArray* roi = [[utils extractROIsFromSeries:series] objectAtIndex:0];
                roiList = [NSDictionary dictionaryWithObject:roi forKey:@"Unnamed"];
            }
            else
                roiList = [utils extractROIsNamedFromSeries:series];
            
            // For each roi return in the dictionary with a name, save it as user_name.roi_series
            for(id roiName in roiList) {
                NSArray* roi = [roiList objectForKey:roiName];
                BOOL isScan = true;
                // Filename for the ROIs:
                NSString* roiNameForFile = @"";
                if([oneFile state] == NSOnState)
                    roiNameForFile = @"AlL"; // specific name for one file for roiName
                else
                    roiNameForFile = [roiName stringByReplacingOccurrencesOfString:@" " withString:@"-"];
                
                // Suffix for File:
                NSString* userWord = [[roiFileName stringValue] stringByDeletingPathExtension];
                if ([userWord isEqualToString:@""])
                    userWord = nil;
                else
                    userWord = [userWord stringByReplacingOccurrencesOfString:@" " withString:@"-"];

                // Filename
                NSString* fileName = @"";
                
                // Get the prefix:
                NSString* suffixROI = @"";
                if (userWord)
                    suffixROI = [NSString stringWithFormat:@"%@_%@_%@", [[filter xnat] xnatUser], userWord, roiNameForFile];
                else
                    suffixROI = [NSString stringWithFormat:@"%@_%@", [[filter xnat] xnatUser], roiNameForFile];
                
                // If process data
                if ([[xnatInfo valueForKey:@"scan"] length] == 0){
                    isScan = false;
                    id strId = series.id;
                    fileName = [NSString stringWithFormat:@"%@_%@.rois_series", strId, suffixROI];
                }else{ //else scan
                    fileName = [NSString stringWithFormat:@"%@.rois_series", suffixROI];
                }

                // Upload
                [self uploadROIToObj:xnatInfo
                              forROI:@[roi]
                        withFileName:fileName
                           overwrite:&overwrite
                              forAll:&forAll
                              onScan:isScan];
                uploaded = true;
            }
        }
        else if(!forAllWarning)
        {
            NSString* message = [NSString stringWithFormat:@"The value set for comment2 for series: %@ doesn't respect the template format of the OsiriX plugin for XNAT.\n\n Please set the comment2 value for the series by following this template: project:{string};subject:{string};session:{string};scan:{string} or project:{string};subject:{string};session:{string};assessor:{string}. Replace the string by the label from XNAT.", [series valueForKey:@"seriesDescription"]];
            forAllWarning = [utils notSeeAnymoreTheAlert:message];
        }
        count += 1;
    }
    if(uploaded)
    {
        [warning setStringValue:@"Done."];
        [warning setTextColor: [NSColor blueColor]];
        [warning displayIfNeeded];
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
        [utils displayMessage:@"ROIs uploaded successfully to XNAT for the selected series/studies."];
    }
    else
    {
        [warning setStringValue:@"Warning: No ROIs uploaded."];
        [warning setTextColor: [NSColor orangeColor]];
        [warning displayIfNeeded];
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
        [utils displayAlert:@"No ROIs uploaded to XNAT."];
    }
    [[self window] close];
}


@end
