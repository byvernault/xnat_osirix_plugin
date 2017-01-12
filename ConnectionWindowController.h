//
//  ConnectionWindowController.h
//  XNAT
//
//  Created by Benjamin Yvernault on 16/10/2015.
//
//

#import <Cocoa/Cocoa.h>


@interface ConnectionWindowController : NSWindowController
{
    // Filter
    XNATFilter* filter;
    
    // text field for xnat info
    IBOutlet NSTextField *xnatHost;
    IBOutlet NSTextField *xnatUser;
    IBOutlet NSTextField *dbName;
    IBOutlet NSSecureTextField *xnatPwd;
    
    // button to browse xnat and download data
    IBOutlet NSButton *connectionButton;
    IBOutlet NSButton *deleteProfileButton;
    
    // NSPopUpButton for profiles + NSArray to store the profiles
    IBOutlet NSPopUpButton * profiles;
    IBOutlet NSPopUpButton * profileDbNames;
    NSMutableArray * profilesJSON;
    
    // Profiles file path
    NSString * profilesFilePath;
}

@property (strong, nonatomic) NSString * profilesFilePath;
@property (strong, nonatomic) NSMutableArray * profilesJSON;

/*INITS/DEALLOC*/
- (id) init:(XNATFilter *)f;
- (id) initWithWindow:(NSWindow *)window;
- (void) windowDidLoad;
- (void) dealloc;

/*METHODS*/
- (void) readPreferences;
- (NSArray*) getProfilesStringFromDict;
- (void) writePreferences;
- (void) addDatabaseToPreferences;
- (int) setFilterClass;
- (id) selectDatabase:(NSString*) database;

/*BUTTON EVENTS*/
- (IBAction) connectionXnat:(NSButton *)sender;
- (IBAction) deleteProfile:(NSButton *)sender;
- (IBAction)fromProfileGetDatabase:(id)sender;

@end
