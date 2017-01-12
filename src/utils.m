//
//  utils.m
//  XNAT
//
//  Tool Box: differents functions usefull through the project with OsiriX / XNAT or just the display.
//
//  Created by Benjamin Yvernault on 16/10/2015.
//
//

#import "utils.h"
#import <DCMObject.h>
#import <DCMAttributeTag.h>
#import <OsiriXAPI/SRAnnotation.h>
#import <Foundation/NSCalendarDate.h>
//#include <map>

/* NSString implementation for containtString */
@interface NSString (ShellExecution)
- (NSString*) runAsCommand;
- (BOOL) isAllDigits;
@end

@implementation NSString (ShellExecution)

- (NSString*)runAsCommand {
    NSPipe* pipe = [NSPipe pipe];
    NSTask* task = [[NSTask alloc] init];
    [task setLaunchPath: @"/bin/sh"];
    [task setArguments:@[@"-c", [NSString stringWithFormat:@"%@", self]]];
    [task setStandardOutput:pipe];
    NSFileHandle* file = [pipe fileHandleForReading];
    [task launch];
    return [[[NSString alloc] initWithData:[file readDataToEndOfFile] encoding:NSUTF8StringEncoding] autorelease];
}

- (BOOL) isAllDigits
{
    NSCharacterSet* nonNumbers = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    NSRange r = [self rangeOfCharacterFromSet: nonNumbers];
    return r.location == NSNotFound;
}

@end


@implementation utils

/*
 Display ALERT message in popup window
 */
+(void)displayAlert:(NSString*) message
{
    NSAlert* alert = [[NSAlert alloc] init];
    NSLog(@"DEBUG - displayAlert: %@", message);
    [alert setMessageText: message];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert runModal];
    [alert release];
}

/*
 Display message in popup window
 */
+(void)displayMessage:(NSString*) message
{
    NSAlert* alert = [[NSAlert alloc] init];
    NSLog(@"DEBUG - displayMessage: %@", message);
    [alert addButtonWithTitle:@"Continue"];
    [alert setMessageText:@"Information:"];
    [alert setInformativeText:message];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert runModal];
    [alert release];
}

/*
 Alert when connecting to XNAT in the plugin: save or not profile
 */
+(BOOL)profileAlert:(NSString*) message
{
    BOOL toSave = false;
    NSAlert*  alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"Continue (w/o saving)"];
    [alert addButtonWithTitle:@"Continue (save profile)"];
    [alert setMessageText:@"Information:"];
    [alert setInformativeText:message];
    [alert setAlertStyle:NSWarningAlertStyle];
    if([alert runModal] == NSAlertSecondButtonReturn)
    {
        toSave = true;
    }
    [alert release];
    return toSave;
}

/*
 Alert to apply action to all for overwrite
 */
+(BOOL)overwriteAlert:(NSString*) message forAll:(BOOL*)forAll
{
    BOOL toOverwrite = false;
    NSAlert*  alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"No"];
    [alert addButtonWithTitle:@"Yes"];
    [alert setShowsSuppressionButton:YES];
    [[alert suppressionButton] setTitle:@"Apply to all."];
    [alert setMessageText:@"Warning:"];
    [alert setInformativeText:message];
    [alert setAlertStyle:NSWarningAlertStyle];
    if([alert runModal] == NSAlertSecondButtonReturn)
    {
        toOverwrite = true;
    }
    *forAll = ([[alert suppressionButton] state] == NSOnState);
    [alert release];
    return toOverwrite;
}

/*
 Alert to apply action not seeing message anymore
 */
+(BOOL)notSeeAnymoreTheAlert:(NSString*) message
{
    BOOL forAll = false;
    NSAlert*  alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"Ok"];
    [alert setShowsSuppressionButton:YES];
    [[alert suppressionButton] setTitle:@"Hide alert."];
    [alert setMessageText:@"Warning:"];
    [alert setInformativeText:message];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert runModal];
    forAll = ([[alert suppressionButton] state] == NSOnState);
    [alert release];
    return forAll;
}

/*
 Get the list of the files in the directory
 */
+(NSMutableArray*)listFilesInDirectory:(NSString*) directory
{
    NSMutableArray * filesPath = [[[NSMutableArray alloc] init] autorelease];
    NSArray * directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:nil];
    for(NSString* file in directoryContent)
    {
        [filesPath addObject:[NSString stringWithFormat:@"%@/%@", directory, file]];
    }
    return filesPath;
}

/*
 Set the Xnat information on the popupbutton
 */
+ (void) setXnatInformation:(NSData *) data
                   forLabel:(NSString*) label
                    onLevel:(int) level
            fromPopUpButton:(NSPopUpButton*) fromButton
              onPopUpButton:(NSPopUpButton*) toButton
{
    // If index 0 selected, don't do anything
    if(fromButton.indexOfSelectedItem != 0)
    {
        NSPopUpButtonCell *buttonCell = [fromButton selectedCell];
        if([buttonCell.title isNotEqualTo:@""])
        {
            if(!data){
                [utils displayAlert:[self messageForLevel:level]];
            }else{
                [toButton addItemsWithTitles: [data valueForKey:label]];
                [toButton setEnabled:true];
            }
        }
    }
}

+ (void) setXnatInformation:(NSData *) data
                   forLabel:(NSString*) label
                    onLevel:(int) level
              fromTextField:(NSTextField*) textField
              onPopUpButton:(NSPopUpButton*) toButton
{
    if(!data){
        [utils displayAlert:[self messageForLevel:level]];
    }else{
        NSArray* uniqueArray = [[NSOrderedSet orderedSetWithArray:[data valueForKey:label]] array];
        [toButton addItemsWithTitles: uniqueArray];
        [toButton setEnabled:true];
    }
}

+(void) resetTextField:(NSTextField*) textField
{
    [textField setStringValue:@""];
    [textField setEnabled:false];
}

/*
 Message for downloading if no data found
 */
+ (NSString*) messageForLevel:(int) level
{
    switch (level) {
        case 0:
            return @"No subjects found for the project selected!";
        case 1:
            return @"No sessions found for the subject selected!";
        case 2:
            return @"No scans found for the session selected!";
        case 3:
            return @"No assessors found for the session selected!";
        case 4:
            return @"No resources found for the scan selected!";
        case 5:
            return @"No resources found for the assessor selected!";
    }
    return @"Error: No object found for the selected arguments!";
}

/*
 Reset the pop up button from the array by removing all the sel and keeping the first empty one
 */
+ (void) resetPopUpButton:(NSPopUpButton*) button
{
    NSMenuItem *firstItem = [button itemAtIndex:0];
    [button removeAllItems];
    [[button menu] addItem:firstItem];
    [button setEnabled:false];
}

/*
 Clear the pop up button using the reset method
 */
+ (void) clearButtons:(NSArray*) buttonArray
{
    for(id button in buttonArray)
    {
        if([button isKindOfClass:[NSPopUpButton class]])
            [self resetPopUpButton:button];
        else if([button isKindOfClass:[NSTextField class]])
            [self resetTextField:button];
        else if([button isKindOfClass:[NSButton class]])
            [button setEnabled:false];
    }
}

/*
 Read the XNAT information stored in the comment2 on OsiriX for the resources downloaded
 return a NSDictionary with project/subject/session/scan
 */
+ (NSDictionary*) readInfoFromComment:(NSString*) comment
{
    NSMutableDictionary* xnatInformation = [[[NSMutableDictionary alloc] init] autorelease];
    NSArray* labels = [comment componentsSeparatedByString:@";"];
    if([labels count] == 4)
    {
        for(NSString* label in labels)
        {
            NSArray* infos = [label componentsSeparatedByString:@":"];
            [xnatInformation setObject:[infos objectAtIndex:1] forKey:[infos objectAtIndex:0]];
        }
        
        // Contains the right keys
        BOOL goodComments = true;
        for(NSString* key in @[@"project", @"subject", @"session"])
        {
            if(![[xnatInformation allKeys] containsObject:key])
                goodComments = false;
        }
        
        if(goodComments)
        {
            // Check if either scan or assessor key
            if([[xnatInformation allKeys] containsObject:@"scan"] || [[xnatInformation allKeys] containsObject:@"assessor"])
                return xnatInformation;
        }
    }

    return @{@"project":@"", @"subject":@"", @"session":@"", @"scan":@""};
}

/*
 Check Version for the assessor: nead to be x.y.z with x,y, and z numbers. Only x is display in the procType
 */
+ (BOOL) isGoodVersion:(NSString*) version
{
    NSArray* vers = [version componentsSeparatedByString:@"."];
    if([vers count] !=3)
    {
        [utils displayAlert:@"Warning: the version given doesn't have the proper format. Please use the logic: x.y.z where x,y, and z are numbers."];
        return false;
    }
    else
    {
        if([[vers objectAtIndex:0] isEqualTo:@""] || ![[vers objectAtIndex:0] isAllDigits])
        {
            [self displayAlert:@"Warning: x from version x.y.z is not a number or not set. Please change it."];
            return false;
        }
        if([[vers objectAtIndex:1] isEqualTo:@""] || ![[vers objectAtIndex:1] isAllDigits])
        {
            [self displayAlert:@"Warning: y from version x.y.z is not a number or not set. Please change it."];
            return false;
        }
        if([[vers objectAtIndex:2] isEqualTo:@""] || ![[vers objectAtIndex:2] isAllDigits])
        {
            [self displayAlert:@"Warning: z from version x.y.z is not a number or not set. Please change it."];
            return false;
        }
    }
    return true;
}

/*
 Create directory and remove it's content if it already exists.
 Return true if the directory is empty, false otherwise
 */
+ (BOOL) createDirectory:(NSString*) directory removeContentIfExists:(BOOL) remove
{
    NSFileManager *fileManager= [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:directory])
    {
        if(remove)
        {
            for (NSString *filename in [fileManager contentsOfDirectoryAtPath:directory error:nil])
                [fileManager removeItemAtPath:[directory stringByAppendingPathComponent:filename] error:NULL];
            return true;
        }
        else
            return false;
    }
    else
        [fileManager createDirectoryAtPath:directory withIntermediateDirectories:true attributes:nil error:nil];
    return true;
}

/*
 Add to the path the variable if not nil
 */
+ (NSString*) addToPath:(NSString*) path string:(NSString*) str
{
    if(str)
    {
        path = [path stringByAppendingString:@"/"];
        path = [path stringByAppendingString:str];
    }
    return path;
}

/*
 From Selection, extract from DicomStudy the DicomSeries and return the NSArray of the DicomSeries
 */
+ (NSArray*) getListImageSeries:(NSArray*) selection
{
    NSMutableArray* listSeries = [[[NSMutableArray alloc] init] autorelease];
    for(id study in selection)
    {
        if([study isKindOfClass: [DicomSeries class]]) {
            if(![listSeries containsObject:study])
                [listSeries addObject:study];
        }else if([study isKindOfClass: [DicomStudy class]]){
            for(DicomSeries* series in [study imageSeries])
                if(![listSeries containsObject:series])
                    [listSeries addObject:series];
        }
    }
    return listSeries;
}

/*
 From Selection, extract from DicomStudy the DicomSeries that are a ROI
 */
+ (NSArray*) getListROISeries:(NSArray*) selection
{
    NSMutableArray* listROISeries = [[[NSMutableArray alloc] init] autorelease];
    for(id study in selection)
    {
        if([study isKindOfClass: [DicomStudy class]]){
            [listROISeries addObject:[study roiSRSeries]];
        }
    }
    return listROISeries;
}

+ (BOOL) isROISeries:(id) series
{
    return [[series valueForKey:@"seriesInstanceUID"] isEqualToString:@"OsiriX ROI SR"];
}

/*
 From Selection Series, get the Dicom Files Path
 */
+ (NSArray*) getDicomFilesForSeriesList:(NSArray*) seriesList
{
    NSMutableArray* listDicomFiles = [[[NSMutableArray alloc] init] autorelease];
    for (id series  in seriesList)
    {
        [listDicomFiles addObject:[self getDicomFilesForSeries:series]];
    }
    return listDicomFiles;
}

+ (NSDictionary*) getDicomFilesForSeries:(id) series
{
    // get the dicom file paths
    NSMutableArray* fpaths = [[[NSMutableArray alloc] init] autorelease];
    for (DicomImage* dImage in [series sortedImages])
        [fpaths addObject:[dImage valueForKey:@"pathString"]];
    
    // Info from comments2
    NSMutableDictionary*  comments = [[[NSMutableDictionary alloc] initWithDictionary:
                                       [self readInfoFromComment:[series valueForKeyPath:@"comment2"]]] autorelease];
    [comments setObject:fpaths forKey:@"files"];
    return comments;
}


/*
 Zip files from NSArray
 */
+ (void) zipFiles:(NSArray*) files asFilePath:(NSString*) zipPath
{
    NSString* zipList = @"";
    for (NSString* fpath in files)
    {
        zipList = [zipList stringByAppendingString:fpath];
        zipList = [zipList stringByAppendingString:@" "];
    }
    NSString* zipCommand = [NSString stringWithFormat:@"zip -j %@ %@", zipPath, zipList];
    [zipCommand runAsCommand];
}


/*
  get Substring between a separator
 */
+ (NSString *)getSubstring:(NSString *)value betweenString:(NSString *)separator1 andString:(NSString *)separator2
{
    NSRange firstInstanceFromTheEnd = [value rangeOfString:separator1 options:NSBackwardsSearch];
    if (firstInstanceFromTheEnd.location == NSNotFound)
        return @"AlL";
    NSUInteger end = [value length] - firstInstanceFromTheEnd.length - firstInstanceFromTheEnd.location;
    if (separator2)
    {
        NSRange secondInstance = [[value substringFromIndex:firstInstanceFromTheEnd.location + firstInstanceFromTheEnd.length] rangeOfString:separator2];
        end = secondInstance.location;
    }
    NSRange finalRange = NSMakeRange(firstInstanceFromTheEnd.location + separator1.length, end);
    
    return [value substringWithRange:finalRange];
}


/*
 Extract from a DicomSeries the Array of ROIs
 */
+ (NSArray*) extractROIsFromSeries:(id) series
{
    // Get the Study from the Series to access the ROI:
    DicomStudy* study = [series valueForKey:@"study"];
    // From the series, for each DicomImages, check if there is a ROI and get the NSData:
    NSArray* imageList = [series sortedImages];
    NSMutableArray* roiSeries = [[[NSMutableArray alloc] init] autorelease];
    for(int i=0; i< [imageList count]; i++)
    {
        NSString* roiPath = [study roiPathForImage:[imageList objectAtIndex:i]];
        if(roiPath)
        {
            NSData *data = [SRAnnotation roiFromDICOM: roiPath];
            //If data, we successfully unarchived from SR style ROI
            NSArray *array = 0L;
            @try
            {
                if (data)
                    array = [NSUnarchiver unarchiveObjectWithData: data];
                else
                    array = [NSUnarchiver unarchiveObjectWithFile: roiPath];
            }
            @catch (NSException * e)
            {
                NSLog( @"failed to read a ROI...");
            }
            if(array)
                [roiSeries addObject:array];
        }else
            [roiSeries addObject:@[]];
    }
    return @[roiSeries];
}

/*
 Extract from a DicomSeries the Array of ROIs with their name
*/
+ (NSDictionary*) extractROIsNamedFromSeries:(id) series
{
    // Get the Study from the Series to access the ROI:
    DicomStudy* study = [series valueForKey:@"study"];
    // From the series, for each DicomImages, check if there is a ROI and get the NSData:
    NSArray* images = [series sortedImages];
    NSUInteger numberImages = [images count];
    NSMutableDictionary* roiSeries = [[[NSMutableDictionary alloc] init] autorelease];
    for(int index=0; index < numberImages; index++)
    {
        NSString* roiPath = [study roiPathForImage:[images objectAtIndex:index]];
        if(roiPath) // if a roi exists, add it to the right list
        {
            NSData *data = [SRAnnotation roiFromDICOM: roiPath];
            //If data, we successfully unarchived from SR style ROI
            NSArray *array = 0L;
            @try
            {
                if (data)
                    array = [NSUnarchiver unarchiveObjectWithData: data];
                else
                    array = [NSUnarchiver unarchiveObjectWithFile: roiPath];
            }
            @catch (NSException * e){NSLog( @"failed to read a ROI...");}
            
            if(array){
                // For each roi in the dicomImage (slice)
                for(int i=0; i<[array count];i++){
                    id roi = [array objectAtIndex:i];
                    NSString* roiName = [roi name];
                    if([roiSeries valueForKey:roiName] != nil)
                        [[[roiSeries objectForKey:roiName] objectAtIndex:index] addObject:roi];
                    else{
                        // Create an empty list of rois for init value:
                        NSMutableArray* roiImage = [[[NSMutableArray alloc] init] autorelease];
                        for (int k=0;k<numberImages; k++){
                            NSMutableArray* roiSlices = [[[NSMutableArray alloc] init] autorelease];
                            [roiImage addObject:roiSlices];
                        }
                        [[roiImage objectAtIndex:index] addObject:roi];
                        [roiSeries setObject:roiImage forKey:roiName];
                    }
                }
            }
        }
    }
    return roiSeries;
}

/*
 Save/load the ROI object in roiList into a file
 */
+ (NSString*) roiSave:(NSArray*) roiList inFile:(NSString *) filePath
{
    if( [roiList count] > 0)
    {
        [NSArchiver archiveRootObject:roiList toFile:filePath];
        if([[NSFileManager defaultManager] fileExistsAtPath:filePath])
            return filePath;
    }
    return nil;
}

+ (NSArray*) roiLoad:(NSString *) filePath
{
    if([[NSFileManager defaultManager] fileExistsAtPath:filePath])
    {
        NSArray* roiList = [NSUnarchiver unarchiveObjectWithFile:filePath];
        if([roiList count] > 0)
            return roiList;
    }
    return nil;
}

/*
 Check if the roiList is not empty meaning if a roi was draw.
 */
+ (BOOL) isROIListEmpty:(NSArray*) roiList
{
    for(id object in [roiList objectAtIndex:0])
    {
        if([object count] > 0)
            return false;
    }
    return true;
}

/*
  Filter List of NSDictionaries
*/
+ (NSArray*) filterListOfDictionaries:(NSArray*) listDict forAttributes:(NSDictionary*) attributes
{
    for(id key in [attributes allKeys])
    {
        NSPredicate* pre = [NSPredicate predicateWithFormat:@"SELF.%@ == %@", key, [attributes valueForKey:key]];
        listDict = [listDict filteredArrayUsingPredicate:pre];
    }
    return listDict;
}

/*
 Change NSArray of dictionary into NSArray of String for error
 */
+ (NSString*) errorAsString:(NSArray*) errorList forType:(NSString*)type
{
    NSString* error = @"";
    for(NSDictionary* errObject in errorList)
    {
        if([type isEqualToString:@"scan"])
            error = [NSString stringWithFormat:@"%@\n - subject: %@ - session: %@ - scan: %@", error,
                     [errObject objectForKey:@"subject_label"],
                     [errObject objectForKey:@"label"],
                     [errObject objectForKey:@"xnat:imagescandata/id"]];
        else if ([type isEqualToString:@"assessor"])
            error = [NSString stringWithFormat:@"%@\n - assessor label: %@ ", error,
                     [errObject objectForKey:@"label"]];
    }
    return error;
}

/*
 Generate scan List for download Scans in the downloadController
 */
+ (NSArray*) getScansListFromIDs:(NSString*) project forSubject:(NSString*) subject forSession:(NSString*) session forScansIDs:(NSArray*) scans
{
    NSMutableArray* scanList = [[[NSMutableArray alloc] init] autorelease];
    for(NSString* scan in [scans valueForKey:@"ID"])
    {
        [scanList addObject:@{@"project":project, @"subject_label":subject, @"label":session, @"xnat:imagescandata/id":scan}];
    }
    return scanList;
}

/*
 Check if a profile (host/user) was already saved
 */
+(BOOL) isProfileAlreadySaved:(NSArray*) profilesJSON forHost:(NSString*) host forUser:(NSString*) user
{
    int index = [self indexForProfile:profilesJSON forHost:host forUser:user];
    if (index >= 0)
        return true;
    else
        return false;
}

/*
 Get index for a pair host/user from the profiles saved
 */
+(int) indexForProfile:(NSArray*) profilesJSON forHost:(NSString*) host forUser:(NSString*) user
{
    for(int i=0; i<[profilesJSON count]; i++)
    {
        NSDictionary* dict = [profilesJSON objectAtIndex:i];
        if([[dict objectForKey:@"host"] isEqualToString:host] && [[dict objectForKey:@"user"] isEqualToString:user])
            return i;
    }
    return -1;
}

/*
 Return host/user from the profiles saved for a specific database
 */
+(NSDictionary*) getProfileForDatabase:(NSArray*) profilesJSON forDataBase:(NSString*) databaseName
{
    for(int i=0; i<[profilesJSON count]; i++)
    {
        NSDictionary* dict = [profilesJSON objectAtIndex:i];
        if([[dict objectForKey:@"databases"] containsObject:databaseName])
            return dict;
    }
    return nil;
}

/*
 Get a list of all databases names
 */
+(NSArray*) databasesFromProfiles:(NSArray*) profilesJSON
{
    NSMutableArray* databases = [[[NSMutableArray alloc] init] autorelease];
    for(int i=0; i<[profilesJSON count]; i++)
        [databases addObjectsFromArray:[[profilesJSON objectAtIndex:i]objectForKey:@"databases"]];
    return databases;
}

/*
 Remove File
 */
+(void) removeROIFile:(NSString*) roiFile
{
    [[NSFileManager defaultManager] removeItemAtPath:roiFile error:nil];
}


@end
