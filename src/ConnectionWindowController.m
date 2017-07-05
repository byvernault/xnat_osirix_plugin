//
//  ConnectionWindowController.m
//  XNAT
//
//  Created by Benjamin Yvernault on 16/10/2015.
//
//

#import "XNATFilter.h"
#import "ConnectionWindowController.h"

@implementation ConnectionWindowController

@synthesize profilesFilePath;
@synthesize profilesJSON;

/* INIT METHODS */
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
    self = [super initWithWindowNibName:@"ConnectionWindowController"];
    
    // Init variables
    filter = f;
    [[self window] setDelegate:(id<NSWindowDelegate>)self];
    
    // Read from preference file each configuration saved
    [self readPreferences];
    [profileDbNames setEnabled:false];
    return self;
}

- (void) dealloc
{
    [profilesJSON release];
    [super dealloc];
}

/* METHODS */
- (void) readPreferences
{
    // Path to preferences/settings on $HOME/.osirix.plugins/XNAT.preferences
    NSString * home = [[[NSProcessInfo processInfo]environment]objectForKey:@"HOME"];
    NSArray *components = [NSArray arrayWithObjects:home, @".osirix.plugins/XNAT.preferences", nil];
    self.profilesFilePath = [NSString pathWithComponents:components];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.profilesFilePath])
        self.profilesJSON = [[NSMutableArray alloc] initWithContentsOfFile:self.profilesFilePath];
    else
        self.profilesJSON = [[NSMutableArray alloc] init];
    
    [profiles addItemsWithTitles:[self getProfilesStringFromDict]];
}

- (NSArray*) getProfilesStringFromDict
{
    NSMutableArray * profilesArray = [[[NSMutableArray alloc] init] autorelease];
    for (NSDictionary * dict in self.profilesJSON)
    {
        NSString * logins = [NSString stringWithFormat:@"Host: %@ - User: %@", [dict objectForKey:@"host"], [dict objectForKey:@"user"]];
        if (logins)
            [profilesArray addObject:logins];
    }
    return profilesArray;
}

-(void) writePreferences
{
    if(![utils isProfileAlreadySaved:self.profilesJSON forHost:[[filter xnat] getRealHost] forUser:[[filter xnat] xnatUser]])
    {
        // data folder:
        NSString * dataFolderValue = [dataFolder stringValue];
        if([dataFolderValue isEqualToString:@""] || dataFolderValue == nil){
            NSString * pluginHomeFolder = [NSString stringWithFormat:@"%@/%@", [[[NSProcessInfo processInfo]environment]objectForKey:@"HOME"], @".osirix.plugins"];
            dataFolderValue = [NSString stringWithFormat:@"%@/%@", pluginHomeFolder, @"osirix_XNAT_data"];
        }
        // Add the new profile:
        NSDictionary * dbDict = @{@"database": [filter osirixDatabaseName],
                                  @"datapath": dataFolderValue};
        NSDictionary * dict = @{@"host" : [[filter xnat] getRealHost],
                                @"user" : [[filter xnat] xnatUser],
                                @"databases": @[dbDict]};
        [self.profilesJSON addObject:dict];
        
        // Create .osirix.plugins if it doesn't exist:
        NSFileManager * fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:self.profilesFilePath]) {
            [fileManager createDirectoryAtPath:[self.profilesFilePath stringByDeletingLastPathComponent]
                   withIntermediateDirectories:YES
                                    attributes:nil
                                         error:nil];
        }

        // If key doesn't exist:
        EMGenericKeychainItem * keyChainItem = [EMGenericKeychainItem genericKeychainItemForService:[[filter xnat] xnatHost]
                                                                                       withUsername:[[filter xnat] xnatUser]];
        if(!keyChainItem)
           [EMGenericKeychainItem addGenericKeychainItemForService:[[filter xnat] xnatHost]
                                                      withUsername:[[filter xnat] xnatUser]
                                                          password:[[filter xnat] xnatPwd]];
        else
            // if it does exist, save password
            [keyChainItem setPassword:[[filter xnat] xnatPwd]];
        
        // Rewrite the profile file
        [self.profilesJSON writeToFile:self.profilesFilePath atomically:YES];
    }
}

-(void) addDatabaseToPreferences
{
    // Add the database
    int index = [utils indexForProfile:self.profilesJSON forHost:[[filter xnat] getRealHost] forUser:[[filter xnat] xnatUser]];
    
    // data folder:
    NSString * dataFolderValue = [dataFolder stringValue];
    if([dataFolderValue isEqualToString:@""] || dataFolderValue == nil){
        NSString * pluginHomeFolder = [NSString stringWithFormat:@"%@/%@", [[[NSProcessInfo processInfo]environment]objectForKey:@"HOME"], @".osirix.plugins"];
        dataFolderValue = [NSString stringWithFormat:@"%@/%@", pluginHomeFolder, @"osirix_XNAT_data"];
    }

    // If databases found:
    NSMutableArray* dbs = [[self.profilesJSON objectAtIndex:index] objectForKey:@"databases"];
    BOOL notFound = TRUE;
    for(id db in dbs)
    {
        if([db isKindOfClass: [NSDictionary class]] && [[db valueForKey:@"database"] isEqualToString:[filter osirixDatabaseName]]){
            [db setValue:dataFolderValue forKey:@"datapath"];
            notFound = FALSE;
            break;
        }else if([db isKindOfClass: [NSString class]] && [db isEqualToString:[filter osirixDatabaseName]]){
            [dbs removeObject:db];
        }
    }
    if(notFound){
        NSLog(@"Adding database with path: %@  -  %@", [filter osirixDatabaseName], dataFolderValue);
        NSDictionary * dbDict = @{@"database": [filter osirixDatabaseName],
                                  @"datapath": dataFolderValue};
        [dbs addObject:dbDict];
    }
    // Rewrite the profile file
    [self.profilesJSON writeToFile:self.profilesFilePath atomically:YES];
}

- (int) setFilterClass
{
    // data folder:
    NSString * dataFolderValue = [dataFolder stringValue];
    if([dataFolderValue isEqualToString:@""] || dataFolderValue == nil){
        NSString * pluginHomeFolder = [NSString stringWithFormat:@"%@/%@", [[[NSProcessInfo processInfo]environment]objectForKey:@"HOME"], @".osirix.plugins"];
        dataFolderValue = [NSString stringWithFormat:@"%@/%@", pluginHomeFolder, @"osirix_XNAT_data"];
    }

    BOOL isDir;
    if ([[NSFileManager defaultManager] fileExistsAtPath:dataFolderValue isDirectory:&isDir])
    {
        if(!isDir)
        {
            [utils displayAlert:@"The data folder is not a valid folder. Please provide an existing folder."];
            return -1;
        }
    }else{
        [utils displayAlert:@"The data folder is not a valid path. Please provide an existing folder."];
        return -1;
    }

    // Set the information on the filter class:
    if ([[xnatHost stringValue] length] > 0)
    {
        [[filter xnat] setRealHost: [xnatHost stringValue]];
        [[filter xnat] setXnatUser: [xnatUser stringValue]];
        [[filter xnat] setXnatPwd: [xnatPwd stringValue]];

        if([[dbName stringValue] length] != 0)
        {
            if([utils getProfile:self.profilesJSON forDataBase:[dbName stringValue]] != nil){
                [utils displayAlert:@"The database name you selected already exists. Please provide an other name."];
                return -1;
            }else
                [filter setOsirixDatabaseName:[dbName stringValue]];
        }else{
            NSString* name = [[[[filter xnat] xnatHost] componentsSeparatedByString:@"/"] objectAtIndex:0];
            [filter setOsirixDatabaseName:name];
        }
        
        if(![utils isProfileAlreadySaved:self.profilesJSON forHost:[xnatHost stringValue] forUser:[xnatUser stringValue]])
            return 1;
        else
            return 0;
    }
    else if(profiles.indexOfSelectedItem != 0)
    {
        NSDictionary * profileDict = [self.profilesJSON objectAtIndex:[profiles indexOfSelectedItem]-1];
        [[filter xnat] setRealHost: [profileDict objectForKey:@"host"]];
        [[filter xnat] setXnatUser: [profileDict objectForKey:@"user"]];
        [[filter xnat] setXnatPwd: [EMGenericKeychainItem passwordForUsername:[[filter xnat] xnatUser] service:[[filter xnat] xnatHost]]];
        if([[[profileDbNames selectedCell] title] length] == 0)
        {
            if([[dbName stringValue] length] >0){
                [filter setOsirixDatabaseName:[dbName stringValue]];
                return 0;
            }else{
                [utils displayAlert:@"You haven't selected a database with your profile."];
                return -1;
            }
        }else{
            [filter setOsirixDatabaseName: [[profileDbNames selectedCell] title]];
            return 0;
        }
    }
    else{
        [utils displayAlert:@"You haven't set your new profile or used a previous profile."];
        return -1;
    }
}

- (id) selectDatabase:(NSString*) database
{
    NSString * dirDB = [NSString stringWithFormat:@"%@/.osirix.plugins/%@",
                        [[[NSProcessInfo processInfo]environment]objectForKey:@"HOME"],
                        database];
    
    BOOL isdir;
    [[NSFileManager defaultManager] fileExistsAtPath:dirDB isDirectory:&isdir];
    if(isdir)
    {
        return [DicomDatabase databaseAtPath:dirDB name:database];
    }else{
        [DicomDir createDicomDirAtDir:dirDB];
        DicomDatabase* xnatDatabase = [[[DicomDatabase alloc] initWithPath:dirDB] autorelease];
        [xnatDatabase setName:database];
        return xnatDatabase;
    }
}

/* BUTTON METHODS */
- (IBAction) deleteProfile:(NSButton *)sender
{
    if(profiles.indexOfSelectedItem != 0)
    {
        NSDictionary * profileDict = [self.profilesJSON objectAtIndex:[profiles indexOfSelectedItem]-1];
        NSString * host = [profileDict objectForKey:@"host"];
        NSString * user = [profileDict objectForKey:@"user"];
    
        // Remove the Key from the Keychain
        EMGenericKeychainItem * keyChainItem = [EMGenericKeychainItem genericKeychainItemForService:host
                                                                                       withUsername:user];
        if(keyChainItem)
            [EMGenericKeychainItem deleteKeychainItem:keyChainItem error:nil];
        
        // Remove the profile from the Preference File.
        int index = [utils indexForProfile:self.profilesJSON forHost:host forUser:user];
        if(index >= 0)
        {
            [self.profilesJSON removeObjectAtIndex:index];
            [self.profilesJSON writeToFile:self.profilesFilePath atomically:YES];
        }
        
        //Clear the profile NSPopUpButton:
        NSMenuItem *nullSubject  = [profiles itemAtIndex:0];
        [profiles removeAllItems];
        [[profiles menu] addItem:nullSubject];
        [profiles addItemsWithTitles:[self getProfilesStringFromDict]];
    }
}

- (IBAction)connectionXnat:(NSButton *)sender
{
    BOOL newProfile = false;
    int status = [self setFilterClass];
    if (status == -1)
        return; // alert message, something is missing from the user
    else if(status == 0)
        newProfile = false;
    else if(status == 1)
        newProfile = true;
    
    id projects = [[filter xnat] listProjects];
    if (!projects)
        [utils displayAlert:@"Connection to XNAT failed! Please check your logins."];
    else{
        NSString* databaseName = [filter osirixDatabaseName];
        // Message
        if(!newProfile)
        {
            [utils displayMessage:[NSString stringWithFormat:@"Connection succeeded with the profile corresponding to the host %@ with the user %@", [[filter xnat] getRealHost], [[filter xnat] xnatUser]]];
        }else{
            BOOL toSave = [utils profileAlert: [NSString stringWithFormat:@"Connection succeeded with a new profile:\n\n    host:  %@\n    user:  %@\n\nDo you want to save it?", [[filter xnat] getRealHost], [[filter xnat] xnatUser]]];
            if(toSave)
                [self writePreferences];
        }
        [self addDatabaseToPreferences];
        
        // Set the data folder:
        [[filter xnat] setDataFolder:[utils getDataFolderFromProfile:[self.profilesJSON objectAtIndex:[profiles indexOfSelectedItem]-1]
                                                         andDatabase:[filter osirixDatabaseName]]];
        NSLog(@"current db: %@ / chosen one: %@", [filter osirixDatabaseName], [[filter xnatDatabase] name]);
        if(![[filter osirixDatabaseName] isEqualToString:[[filter xnatDatabase] name]])
        {
            // Set the filter database
            [filter setXnatDatabase:[self selectDatabase:databaseName]];
            [[filter xnat] setDatabaseName:[filter osirixDatabaseName]];
            [[BrowserController currentBrowser] setDatabase:[filter xnatDatabase]];
        }

        // Close window
        [[self window] close];
    }
}

- (IBAction)browseForFolder:(NSButton *)sender
{
    NSString* folder = [utils getDirectoryFolder];
    [dataFolder setStringValue:folder];
}

- (IBAction)fromProfileGetDatabase:(id)sender
{
    NSString* profile = [[profiles selectedCell] title];
    if([profile length] ==0)
    {
        [utils resetPopUpButton:profileDbNames];
        [profileDbNames setEnabled:false];
        return;
    }
    else{
        NSArray* databases = [utils databasesFromProfile: [self.profilesJSON objectAtIndex:[profiles indexOfSelectedItem]-1]];
        [profileDbNames addItemsWithTitles:databases];
        [profileDbNames setEnabled:true];
    }
}

@end
