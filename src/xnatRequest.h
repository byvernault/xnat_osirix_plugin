//
//  xnatRequest.h
//  XNAT
//
//  Created by Benjamin Yvernault on 16/10/2015.
//
//

#import <Foundation/Foundation.h>

@interface xnatRequest : NSObject
{
    //URL connection
    NSURLConnection * connection;
    NSMutableData * buffer;
    //String
    NSString* protocol;
    NSString* xnatHost;
    NSString* xnatUser;
    NSString* xnatPwd;
    // Temp Folder for download
    NSString* dataFolder;
    NSString* databaseName;
    NSString* pluginHomeFolder;    
}

@property (strong, nonatomic) NSURLConnection * connection;
@property (strong, nonatomic) NSMutableData * buffer;
@property (strong, nonatomic) NSString * protocol;
@property (strong, nonatomic) NSString * xnatHost;
@property (strong, nonatomic) NSString * xnatUser;
@property (strong, nonatomic) NSString * xnatPwd;
@property (strong, nonatomic) NSString * databaseName;
@property (strong, nonatomic) NSString * dataFolder;
@property (strong, nonatomic) NSString * pluginHomeFolder;

/* Methods to init */
- (id) initWithHost: (NSString *) host andUser: (NSString *) user andPwd: (NSString *) pwd;
- (id) init;
- (void) initPaths;
- (void) dealloc;
- (void) setRealHost:(NSString*) host;
- (NSString*) getRealHost;

/* random Methods */
- (BOOL) arrayOfDict:(NSArray*) array hasKey:(NSString*) key;
- (NSString*) getAuthentification;
- (NSString *)mimeTypeForPath:(NSString *)path;
- (NSString *)generateBoundaryString;
- (NSData *)createBodyWithBoundary:(NSString *)boundary
                             paths:(NSArray *)paths
                         fieldName:(NSString *)fieldName;

// Get the URL string format for request
- (NSString*) generateXnatUrl:(NSString*) xnatPath withSuffix:(NSString*) Suffix;

// Generate the path on XNAT for data:
// project
- (NSString*) generateXnatPath:(NSString*) project;
// subject
- (NSString*) generateXnatPath:(NSString*) project forSubject:(NSString*) subject;
// session
- (NSString*) generateXnatPath:(NSString*) project forSubject:(NSString*) subject forSession:(NSString*) session;
// scans and all
- (NSString*) generateXnatPath:(NSString*) project forSubject:(NSString*) subject forSession:(NSString*) session forScan:(NSString*) scan;
- (NSString*) generateXnatPath:(NSString*) project forSubject:(NSString*) subject forSession:(NSString*) session forScan:(NSString*) scan
                   forResource:(NSString*) resource;
- (NSString*) generateXnatPath:(NSString*) project forSubject:(NSString*) subject forSession:(NSString*) session forScan:(NSString*) scan
                   forResource:(NSString*) resource forFile:(NSString*) file;
- (NSString*) generateXnatPathScan:(NSDictionary*) scanInfo;
- (NSString*) generateXnatPathScan:(NSDictionary*) scanInfo forResource:(NSString*) resource;
- (NSString*) generateXnatPathScan:(NSDictionary*) scanInfo forResource:(NSString*) resource forFile:(NSString*) file;
// assessors and all
- (NSString*) generateXnatPath:(NSString*) project forSubject:(NSString*) subject forSession:(NSString*) session forAssessor:(NSString*) assessor;
- (NSString*) generateXnatPath:(NSString*) project forSubject:(NSString*) subject forSession:(NSString*) session forAssessor:(NSString*) assessor
                   forResource:(NSString*) resource;
- (NSString*) generateXnatPath:(NSString*) project forSubject:(NSString*) subject forSession:(NSString*) session forAssessor:(NSString*) assessor
                   forResource:(NSString*) resource forFile:(NSString*) file;
- (NSString*) generateXnatPathAssessor:(NSString*) assessor;
- (NSString*) generateXnatPathAssessor:(NSString*) assessor forResource:(NSString*) resource;
- (NSString*) generateXnatPathAssessor:(NSString*) assessor forResource:(NSString*) resource forFile:(NSString*) file;

// Get the assessor label
- (NSString*) getAssessorLabel:(NSString*) project
                    forSubject:(NSString*) subject
                    forSession:(NSString*) session
                       forScan:(NSString*) scan
                   forProctype:(NSString*) procType;
- (NSString*) getOsiriXAssessorLabel:(NSString*) project forSubject:(NSString*) subject forSession:(NSString*) session;
- (NSString*) getAssessorLabel:(NSString*) project
                    forSubject:(NSString*) subject
                    forSession:(NSString*) session
                       forScan:(NSString*) scan
                   forProcName:(NSString*) procName
                   withVersion:(NSString*) version
                    withSuffix:(NSString*) suffix;
- (NSString*) generateProcType:(NSString*)procName withVersion:(NSString*)version withSuffix:(NSString*)suffix;

// Get info from assessor label
- (NSDictionary*) extractInfoFromAssessor:(NSString*) assessor;

- (BOOL) objectExistsOnXnat:(NSDictionary*) xnatInfo;
- (NSArray*) datatypesXnat;
- (BOOL) hasDAXdatatypes;

/* List of objects from XNAT */
- (id) listForXnatPath:(NSString*) xnatPath urlSuffix:(NSString*) urlSuffix sortBy:(NSString*) sortedKey;
- (NSArray*) listProjectsOwned;
- (id) listProjects;
- (id) listSubjectsForProject:(NSString*) project;
- (id) listSessionsForProject:(NSString*) project andSubject:(NSString*) subject;
- (id) listScansForProject:(NSString*) project;
- (id) listScansForProjectWithResource:(NSString*) project;
- (id) listScansForProject:(NSString*) project andSubject:(NSString*) subject andSession:(NSString*) session;
- (id) listScansForProject:(NSString*) project andSubject:(NSString*) subject andSession:(NSString*) session andType:(NSString*) types;
- (id) listResourcesForProject:(NSString*) project andSubject:(NSString*) subject andSession:(NSString*) session andScan:(NSString*) scan;
- (id) listFilesForProject:(NSString*) project
                andSubject:(NSString*) subject
                andSession:(NSString*) session
                   andScan:(NSString*) scan
               andResource:(NSString*) resource;
- (id) listAssessorsForProject:(NSString*) project;
- (id) listAssessorsForProjectWithResource:(NSString*) project;
- (id) listAssessorsForProject:(NSString*) project andSubject:(NSString*) subject andSession:(NSString*) session;
- (id) listOutResourcesForProject:(NSString*) project
                       andSubject:(NSString*) subject
                       andSession:(NSString*) session
                      andAssessor:(NSString*) assessor;
- (id) listOutFilesForProject:(NSString*) project
                   andSubject:(NSString*) subject
                   andSession:(NSString*) session
                  andAssessor:(NSString*) assessor
                  andResource:(NSString*) resource;
- (id) listFilesForAssessor:(NSString*) assessor andResource:(NSString*) resource;

/* Methods related to XNAT */
- (NSArray*) downloadFromScan:(NSString*) project
                   forSubject:(NSString*) subject
                   forSession:(NSString*) session
                      forScan:(NSString*) scan
                  forResource:(NSString*) resource;
- (NSString*) downloadFromScan:(NSString*) project
                    forSubject:(NSString*) subject
                    forSession:(NSString*) session
                       forScan:(NSString*) scan
                   forResource:(NSString*) resource
                       forFile:(NSString*) file;
- (NSArray*) downloadFromAssessor:(NSString*) assessor
                      forResource:(NSString*) resource;
- (BOOL) resourceExistsforAssessor:(NSString*) assessor forResource:(NSString*) resource;
- (NSString*) downloadFromAssessor:(NSString*) assessor
                      forResource:(NSString*) resource
                          forFile:(NSString*) file;
- (BOOL) fileExistsforAssessor:(NSString*) assessor forResource:(NSString*) resource forFile:(NSString*) file;
- (BOOL) fileExistsforScan:(NSDictionary*) scanInfo forResource:(NSString*) resource forFile:(NSString*) file;
- (void) uploadZipFile:(NSString*) zipPath
             toProject:(NSString*) project
             toSubject:(NSString*) subject
             toSession:(NSString*) session
                toScan:(NSString*) scan
            toResource:(NSString*) resource;
- (void) uploadZipFile:(NSString*) zipPath
                toScan:(NSDictionary*) scanInfo
            toResource:(NSString*) resource;
- (void) uploadZipFile:(NSString*) zipPath
             toProject:(NSString*) project
             toSubject:(NSString*) subject
             toSession:(NSString*) session
                toScan:(NSString*) scan
            toProcName:(NSString*) procName
           withVersion:(NSString*) version
            withSuffix:(NSString*) suffix
            toResource:(NSString*) resource;
- (void) uploadZipFile:(NSString*) zipPath
            toAssessor:(NSString*) assessor
            toResource:(NSString*) resource;
- (void) uploadFile:(NSString*) filePath
          toProject:(NSString*) project
          toSubject:(NSString*) subject
          toSession:(NSString*) session
             toScan:(NSString*) scan
         toResource:(NSString*) resource
          overwrite:(BOOL) overwrite;
- (void) uploadFile:(NSString*) filePath
             toScan:(NSDictionary*) scanInfo
         toResource:(NSString*) resource
          overwrite:(BOOL) overwrite;
- (void) uploadFile:(NSString*) filePath
          toProject:(NSString*) project
          toSubject:(NSString*) subject
          toSession:(NSString*) session
             toScan:(NSString*) scan
         toProcName:(NSString*) procName
        withVersion:(NSString*) version
         withSuffix:(NSString*) suffix
         toResource:(NSString*) resource
          overwrite:(BOOL) overwrite;
- (void) uploadFile:(NSString*) filePath
         toAssessor:(NSString*) assessor
         toResource:(NSString*) resource
          overwrite:(BOOL) overwrite;
- (void) uploadSnapshotsAssessor:(NSString*) assessor;
- (void) createAssessor:(NSString*) assessor
            withVersion:(NSString*) version
             withStatus:(NSString*) qcstatus;
- (void) createAssessorOnProject:(NSString*) project
                      forSubject:(NSString*) subject
                      forSession:(NSString*) session
                         forScan:(NSString*) scan
                        withProc:(NSString*) procName
                      withSuffix:(NSString*) suffix
                     withVersion:(NSString*) version
                      withStatus:(NSString*) status;
- (void) createDefaultOsirixOnProject:(NSString*) project
                           forSubject:(NSString*) subject
                           forSession:(NSString*) session;
- (void) editQCStatus:(NSString*) assessor
           withStatus:(NSString*) qcStatus
          usingMethod:(NSString*) method
            withNotes:(NSString*) notes;
- (BOOL) assessorExists:(NSString*) assessor;
- (BOOL) assessorExists:(NSString*) project
             forSubject:(NSString*) subject
             forSession:(NSString*) session
                forScan:(NSString*) scan
           withProcName:(NSString*) procName
             withSuffix:(NSString*) suffix
            withVersion:(NSString*)version;

/* API calls */
- (NSString*) downloadURL:(NSURL*)url toFile:(NSString*) filePath;
- (NSArray*) downloadURL:(NSURL*)url toDirectory:(NSString*) directory;
- (void) uploadURL:(NSURL *)url forFile:(NSString *)zipPath;
- (void) getRequest:(NSURL *)url withBody:(NSData*) httpBody withContentType:(NSString*) contentType;
- (void) postRequest:(NSURL *)url withBody:(NSData*) httpBody withContentType:(NSString*) contentType;
- (void) putRequest:(NSURL *)url withBody:(NSData*) httpBody withContentType:(NSString*) contentType;

@end
