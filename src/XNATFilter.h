//
//  XNATFilter.h
//  XNAT
//
//  Copyright (c) 2015 Benjamin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OsiriXAPI/PluginFilter.h>

@interface XNATFilter : PluginFilter {
    /* Variables */
    // XNAT
    xnatRequest* xnat;
    // OsiriX database:
    DicomDatabase* xnatDatabase;
    // Osirix database name:
    NSString* osirixDatabaseName;
    
    // Store XNAT list of project:
    NSArray* projectsXnat;
}

@property (retain) xnatRequest* xnat;
@property (retain) NSArray* projectsXnat;
@property (retain) DicomDatabase* xnatDatabase;
@property (retain) NSString* osirixDatabaseName;

- (void) initPlugin;
- (long) filterImage:(NSString*) menuName;
- (BOOL) isDataBaseGood;

@end
