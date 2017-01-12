//
//  uploadAllWindowController.h
//  XNAT
//
//  Created by Benjamin Yvernault on 02/11/2015.
//
//

#import <Cocoa/Cocoa.h>

@interface uploadAllWindowController : NSWindowController
{
    XNATFilter	*filter;
    
    // button to browse xnat and download data
    IBOutlet NSButton *uploadButton;
    IBOutlet NSButton *oneFile;
    
    /* text field */
    // new assessor
    IBOutlet NSTextField *roiFileName;
    
    // new assessor
    IBOutlet NSTextField *warning;
    
}

/* INITS/DEALLOC */
- (id) init:(XNATFilter *)f;
- (id) initWithWindow:(NSWindow *)window;
- (void) windowDidLoad;
- (void) dealloc;

/* METHODS */
- (void) uploadFile:(NSString*) roiFile
       onXnatObject:(NSDictionary*) xnatInfo
          overwrite:(BOOL) overwrite
             onScan:(BOOL) scan;
- (BOOL) fileExists:(NSString*) roiFile
       onXnatObject:(NSDictionary*) xnatInfo
             onScan:(BOOL) scan;
- (void) uploadROIToObj:(NSDictionary*) scanInfo
                 forROI:(NSArray*) roiList
           withFileName:(NSString*) fileName
              overwrite:(BOOL*) overwrite
                 forAll:(BOOL*) forAll
                 onScan:(BOOL) scan;

/* BUTTON METHODS */
- (IBAction) uploadData:(id)sender;

@end
