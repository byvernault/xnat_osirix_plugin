//
//  XNATFilter.m
//  XNAT
//
//  Copyright (c) 2015 Benjamin. All rights reserved.
//

#import "XNATFilter.h"
#import "downloadWindowController.h"
#import "uploadAllWindowController.h"
#import "QualityControlWindowController.h"
#import "ConnectionWindowController.h"

@implementation XNATFilter

@synthesize xnat;
@synthesize xnatDatabase;
@synthesize projectsXnat;
@synthesize osirixDatabaseName;

- (void) initPlugin
{
    //Initialisation
    self.xnat = [[xnatRequest alloc] init];
    //Init the db to nothing:
    self.xnatDatabase = nil;
    //Init the db to nothing:
    self.osirixDatabaseName = @"";
}

- (void) dealloc
{
    if(self.projectsXnat)
        [self.projectsXnat release];
    self.projectsXnat = nil;
    [xnat release];
    [xnatDatabase release];
    osirixDatabaseName = nil;
    [super dealloc];
}

- (long) filterImage:(NSString*) menuName
{
    if([menuName  isEqual: @"connection"]){
        ConnectionWindowController* connectionWindow = [[ConnectionWindowController alloc] init:self];
        [connectionWindow showWindow:self];
        
    }
    else if([menuName  isEqual: @"download scans"]){
        if([self isDataBaseGood])
        {
            downloadWindowController* downloadXnat = [[downloadWindowController alloc] init:self];
            [downloadXnat showWindow:self];
        }
    }
    else if ([menuName  isEqual: @"upload ROIs"]){
        if([self isDataBaseGood])
        {
            uploadAllWindowController* uploadAllXnat = [[uploadAllWindowController alloc] init:self] ;
            [uploadAllXnat showWindow:self];
        }
    }
    else if ([menuName  isEqual: @"quality control"]){
        if([self isDataBaseGood])
        {
            QualityControlWindowController* qcControl = [[QualityControlWindowController alloc] init:self];
            [qcControl showWindow:self];
        }
    }
    
    return 0;
}

- (BOOL) isDataBaseGood
{
    // Get current database
    DicomDatabase* currentDatabase = [[BrowserController currentBrowser] database];
    NSString* name = [currentDatabase name];
    // Removing the " DB" if present:
    if([name hasSuffix:@" DB"]){
        name = [name substringToIndex:[name length] -3];
    }
    // If not initialise, get the xnat info from the preferences file for the database selected
    if([[self.xnat xnatHost] length] == 0 || [self.osirixDatabaseName isNotEqualTo:name])
    {
        // Path to preferences/settings on $HOME/.osirix.plugins/XNAT.preferences
        NSString * home = [[[NSProcessInfo processInfo]environment] objectForKey:@"HOME"];
        NSArray *components = [NSArray arrayWithObjects:home, @".osirix.plugins/XNAT.preferences", nil];
        NSString* profilesFilePath = [NSString pathWithComponents:components];
        NSMutableArray * profilesJSON = nil;
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:profilesFilePath])
            profilesJSON = [[[NSMutableArray alloc] initWithContentsOfFile:profilesFilePath] autorelease];
        else
            profilesJSON = [[[NSMutableArray alloc] init] autorelease];
        
        NSDictionary* profileDict = [utils getProfileForDatabase:profilesJSON forDataBase:name];
        if(profileDict)
        {
            [self.xnat setRealHost: [profileDict objectForKey:@"host"]];
            [self.xnat setXnatUser: [profileDict objectForKey:@"user"]];
            [self.xnat setDatabaseName:name];
            [self.xnat setXnatPwd: [EMGenericKeychainItem passwordForUsername:[self.xnat xnatUser] service:[self.xnat xnatHost]]];
            self.osirixDatabaseName = name;
            self.xnatDatabase = [currentDatabase retain];
            return true;
        }else
        {
            [utils displayAlert:@"XNAT information not set and database not associated to a XNAT settings saved on your computer. \n\nPlease use the top menu:\n Plugins->Database->XNAT->connection."];
            return false;
        }
    }
    return true;
}


@end
