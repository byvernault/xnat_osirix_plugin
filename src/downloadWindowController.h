//
//  downloadWindowController.h
//  XNAT
//
//  Created by Benjamin Yvernault on 13/10/2015.
//
//

#import <AppKit/AppKit.h>
#import <Cocoa/Cocoa.h>

@interface downloadWindowController : NSWindowController
{
    XNATFilter	*filter;
    
    //CurrentBrowser:
    BrowserController* currentBrowser;
    
    //Viewer
    ViewerController* viewer;
        
    // button to browse xnat and download data
    IBOutlet NSButton *downloadButton;
    IBOutlet NSButton *selectAll;
    IBOutlet NSButton *checkROI;
    IBOutlet NSButton *query;
    
    // Array for scans
    IBOutlet NSTableView *tableView;
    IBOutlet NSArrayController *arrayController;
    
    // display subjects/sessions/a-s labels/resources
    IBOutlet NSPopUpButton *xnatProject;
    IBOutlet NSPopUpButton *xnatSubject;
    IBOutlet NSPopUpButton *xnatSession;
    IBOutlet NSPopUpButton *scanTypes;
    
    // ROI
    IBOutlet NSTextField *RoiFilename;
    
    //Download
    IBOutlet NSProgressIndicator* downloadProgress;
    IBOutlet NSTextField *progressPercent;
    
    //Warning
    IBOutlet NSTextField *warning;
    IBOutlet NSTextField *warning2;
    
    // Other variables
    NSArray* scansData;
    NSArray* tableData;
}

@property (retain) BrowserController* currentBrowser;
@property (retain) ViewerController* viewer;
@property (retain) NSArray* scansData;
@property (retain) NSArray* tableData;
@property (assign) IBOutlet NSTableView *tableView;
@property (assign) IBOutlet NSArrayController* arrayController;

/* INIT METHODS*/
- (id) init:(XNATFilter *)f;
- (id) initWithWindow:(NSWindow *)window;
- (void) windowDidLoad;
- (void) dealloc;

/* Methods for table*/
- (void) populateTable;
- (void) clearTable;

/*METHODS*/
- (void) loadROI:(NSString*) roiFile onSeries:(DicomSeries*) series withName:(NSString*) roiName;
- (BOOL) downloadScan:(NSString*) project forSubject:(NSString*) subject forSession:(NSString*) session forScan:(NSString*) scan
          forResource:(NSString*) resource;
- (void) downloadScans:(NSArray*) xnatObjects;

/*BUTTON EVENTS*/
- (IBAction)downloadFromXnat:(NSButton *)sender;
- (IBAction)queryXnat:(NSButton *)sender;
- (IBAction)fromSelectedProjectGetAllScans:(NSPopUpButton *)sender;
- (IBAction)fromSelectedSubjectSetSessions:(NSPopUpButton *)sender;
- (IBAction)fromSelectedSessionSetType:(NSPopUpButton *)sender;
- (IBAction)selectAllScans:(NSButton *)sender;
- (IBAction)checkROIFilenameXNAT:(NSButton *)sender;
- (IBAction) columnChangeSelected:(id)sender;

@end
