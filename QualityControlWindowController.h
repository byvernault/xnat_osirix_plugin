//
//  QualityControlWindowController.h
//  XNAT
//
//  Created by Benjamin Yvernault on 17/12/2015.
//
//

#import <AppKit/AppKit.h>
#import <Cocoa/Cocoa.h>

@interface QualityControlWindowController : NSWindowController
{
    // Filter Object
    XNATFilter* filter;
    
    //CurrentBrowser:
    BrowserController* currentBrowser;
    
    //Viewer
    ViewerController* viewer;
    
    // IBOutlet objects
    IBOutlet NSTableView* tableView;
    IBOutlet NSButton *query;
    IBOutlet NSPopUpButton* xnatProject;
    IBOutlet NSPopUpButton* xnatSubject;
    IBOutlet NSPopUpButton* xnatSession;
    IBOutlet NSPopUpButton* assessorProctype;
    IBOutlet NSPopUpButton* assessorProcStatus;
    IBOutlet NSPopUpButton* assessorqcStatus;
    IBOutlet NSArrayController* arrayController;
    IBOutlet NSButton* selectAll;
    IBOutlet NSPopUpButton* qcStatus;
    IBOutlet NSTextField* method;
    IBOutlet NSTextField* notes;
    IBOutlet NSButton* submit;
    IBOutlet NSButton* downloadOsirix;
    
    // ROI
    IBOutlet NSButton *checkROI;
    IBOutlet NSTextField *RoiFilename;
    
    // Other variables
    NSArray* assessorsData;
    NSArray* tableData;
    
    //Warning
    IBOutlet NSTextField *warning;
    IBOutlet NSTextField *warning2;
}

@property (retain) BrowserController* currentBrowser;
@property (retain) ViewerController* viewer;
@property (retain) NSArray* assessorsData;
@property (retain) NSArray* tableData;
@property (assign) IBOutlet NSTableView *tableView;
@property (assign) IBOutlet NSArrayController* arrayController;

/* Init Methods */
- (id) initWithWindow:(NSWindow *)window;
- (void) windowDidLoad;
- (id) init:(XNATFilter*) f;
- (void) dealloc;

/* Methods */
- (void) populateTable;
- (void) disableQCBox;
- (void) enableQCBox;
- (void) clearTable;
- (void) qualityControlAssessors:(NSArray*) xnatObjects;
- (void) loadROI:(NSString*) roiFile onSeries:(DicomSeries*) series withName:(NSString*) roiName;
- (BOOL) downloadAssessor:(NSString*) assessorLabel forResource:(NSString*) resource;
- (void) downloadOsirixData:(NSArray*) xnatObjects;

/* Button Action */
- (IBAction) fromSelectedProjectGetAllAssessors:(NSPopUpButton *)sender;
- (IBAction) fromSelectedSubjectSetSessions:(NSPopUpButton *)sender;
- (IBAction) queryXnat:(NSButton *)sender;
- (IBAction) selectAllProcesses:(id)sender;
- (IBAction) columnChangeSelected:(id)sender;
- (IBAction) submitQualityControl:(id)sender;
- (IBAction) downloadDataFromXnat:(NSButton *)sender;
- (IBAction) checkROIFilenameXNAT:(NSButton *)sender;

@end
