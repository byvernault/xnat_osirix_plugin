//
//  xnatRequest.m
//  XNAT
//
//  Created by Benjamin Yvernault on 16/10/2015.
//
//
#import "utils.h"
#import "xnatRequest.h"

/* NSString implementation for containtString */
@interface NSString (ShellExecution)
- (NSString*)runAsCommand;
- (BOOL)containsString:(NSString *)string;
- (BOOL)containsString:(NSString *)string
               options:(NSStringCompareOptions)options;
@end

@implementation NSString (ShellExecution)

- (NSString*)runAsCommand {
    NSPipe* pipe = [NSPipe pipe];
    NSTask* task = [[[NSTask alloc] init] autorelease];
    [task setLaunchPath: @"/bin/sh"];
    [task setArguments:@[@"-c", [NSString stringWithFormat:@"%@", self]]];
    [task setStandardOutput:pipe];
    NSFileHandle* file = [pipe fileHandleForReading];
    [task launch];
    return [[[NSString alloc] initWithData:[file readDataToEndOfFile] encoding:NSUTF8StringEncoding] autorelease];
}

- (BOOL)containsString:(NSString *)string
               options:(NSStringCompareOptions)options {
    NSRange rng = [self rangeOfString:string options:options];
    return rng.location != NSNotFound;
}

- (BOOL)containsString:(NSString *)string {
    return [self containsString:string options:0];
}

@end

/* xnatRequest implementation */
@implementation xnatRequest

@synthesize connection;
@synthesize buffer;
@synthesize protocol;
@synthesize xnatHost;
@synthesize xnatUser;
@synthesize xnatPwd;
@synthesize databaseName;
@synthesize dataFolder;
@synthesize pluginHomeFolder;

/* Methods to init */
- (id) initWithHost: (NSString *) host andUser: (NSString *) user andPwd: (NSString *) pwd
{
    if (self = [super init])
    {
        self.buffer = nil;
        self.connection = nil;
        self.protocol = @"";
        [self setRealHost:host];
        self.xnatUser = user;
        self.xnatPwd = pwd;
        [self initPaths];
    }
    return self;
}

- (id) init
{
    if ( self = [super init] ) {
        self.buffer = nil;
        self.connection = nil;
        self.xnatHost = @"";
        self.xnatUser = @"";
        self.xnatPwd = @"";
        self.protocol = @"";
        [self initPaths];
    }
    return self;
}

- (void) initPaths
{
    self.pluginHomeFolder = [NSString stringWithFormat:@"%@/%@", [[[NSProcessInfo processInfo]environment]objectForKey:@"HOME"], @".osirix.plugins"];
    self.dataFolder = [NSString stringWithFormat:@"%@/%@", self.pluginHomeFolder, @"osirix_XNAT_data"];
    [utils createDirectory:self.dataFolder removeContentIfExists:false];
}

- (void) dealloc
{
    if(buffer)
        [buffer release];
    if(connection)
        [connection release];
    [xnatHost release];
    [xnatUser release];
    [xnatPwd release];
    [pluginHomeFolder release];
    [dataFolder release];
    [protocol release];
    [super dealloc];
}

- (void) setRealHost:(NSString*) host
{
    if ([host containsString:@"https"]){
        self.protocol = @"https";
        host = [host substringWithRange:NSMakeRange(8, [host length]-8)];
    }
    else if ([host containsString:@"http"]){
        self.protocol = @"http";
        host = [host substringWithRange:NSMakeRange(7, [host length]-7)];
    }
    self.xnatHost = host;
}

- (NSString*) getRealHost
{
    return [NSString stringWithFormat:@"%@://%@", self.protocol, self.xnatHost];
}

/* random Methods */
- (BOOL) arrayOfDict:(NSArray*) array hasKey:(NSString*) key
{
    if([array count] ==0)
        return false;
    else
    {
        if ([[array objectAtIndex:0] objectForKey:key])
            return true;
        else
            return false;
    }
}

- (NSString *) getAuthentification
{
    NSString *authenticationString = [NSString stringWithFormat:@"%@:%@", self.xnatUser, self.xnatPwd];
    NSData *authenticationData = [authenticationString dataUsingEncoding:NSASCIIStringEncoding];
    return [authenticationData base64Encoding];
}

- (NSString *)mimeTypeForPath:(NSString *)path
{
    // get a mime type for an extension using MobileCoreServices.framework
    CFStringRef extension = (__bridge CFStringRef)[path pathExtension];
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, extension, NULL);
    assert(UTI != NULL);

    NSString *mimetype = CFBridgingRelease(UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType));
    if ([mimetype length] == 0 && [[path pathExtension] isEqualToString:@"rois_series"]) // for rois_series for example
        mimetype = @"text/rtf";
    else
        assert(mimetype != NULL);
    
    CFRelease(UTI);
    
    return mimetype;
}

- (NSString *)generateBoundaryString
{
    return [NSString stringWithFormat:@"Boundary-%@", [[NSUUID UUID] UUIDString]];
}

- (NSData *)createBodyWithBoundary:(NSString *)boundary
                             paths:(NSArray *)paths
                         fieldName:(NSString *)fieldName
{
    NSMutableData *httpBody = [NSMutableData data];
    // add files
    for (NSString *path in paths) {
        NSString *filename  = [path lastPathComponent];
        NSData   *data      = [NSData dataWithContentsOfFile:path];
        NSString *mimetype  = [self mimeTypeForPath:path];
        
        [httpBody appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [httpBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", fieldName, filename] dataUsingEncoding:NSUTF8StringEncoding]];
        [httpBody appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n\r\n", mimetype] dataUsingEncoding:NSUTF8StringEncoding]];
        [httpBody appendData:data];
        [httpBody appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    }
    [httpBody appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    return httpBody;
}

/*
 Get the full URL for XNAT with the xnatPath
 */
-(NSString*) generateXnatUrl:(NSString*) xnatPath withSuffix:(NSString*) suffix
{
    NSString* xnatUrl = [NSString stringWithFormat:@"%@/REST/%@", [self getRealHost], xnatPath];
    if(suffix)
        xnatUrl = [xnatUrl stringByAppendingString:suffix];
    return xnatUrl;
}

/*
 Get xnatPath for project, if nil, all projects
 */
-(NSString*) generateXnatPath:(NSString*) project
{
    NSString* path = @"projects";
    return [utils addToPath:path string:project];
}

/*
 Get xnatPath for subject, if nil, all subjects
 */
-(NSString*) generateXnatPath:(NSString*) project
                   forSubject:(NSString*) subject
{
    NSString* path = [[self generateXnatPath:project] stringByAppendingString:@"/subjects"];
    return [utils addToPath:path string:subject];
}

/*
 Get xnatPath for session, if nil, all sessions
 */
-(NSString*) generateXnatPath:(NSString*) project
                   forSubject:(NSString*) subject
                   forSession:(NSString*) session
{
    NSString* path = [[self generateXnatPath:project forSubject:subject] stringByAppendingString:@"/experiments"];
    return [utils addToPath:path string:session];
}

/*
 Get xnatPath for scan, if nil, all scans
 */
-(NSString*) generateXnatPath:(NSString*) project
                   forSubject:(NSString*) subject
                   forSession:(NSString*) session
                      forScan:(NSString*) scan
{
    NSString* path = [[self generateXnatPath:project forSubject:subject forSession:session] stringByAppendingString:@"/scans"];
    return [utils addToPath:path string:scan];
}

/*
 Get xnatPath for resource for scan, if nil, all resources
 */
-(NSString*) generateXnatPath:(NSString*) project
                   forSubject:(NSString*) subject
                   forSession:(NSString*) session
                      forScan:(NSString*) scan
                  forResource:(NSString*) resource
{
    NSString* path = [[self generateXnatPath:project forSubject:subject forSession:session forScan:scan] stringByAppendingString:@"/resources"];
    return [utils addToPath:path string:resource];
}

/*
 Get xnatPath for file on a resource for a scan, if nil, all files
 */
-(NSString*) generateXnatPath:(NSString*) project
                   forSubject:(NSString*) subject
                   forSession:(NSString*) session
                      forScan:(NSString*) scan
                  forResource:(NSString*) resource
                      forFile:(NSString*) file
{
    NSString* path = [[self generateXnatPath:project forSubject:subject forSession:session forScan:scan forResource:resource]
                      stringByAppendingString:@"/files"];
    return [utils addToPath:path string:file];
}

/*
 Get xnatPath for scan and resources and files by giving only the scan information dictionary
 */
- (NSString*) generateXnatPathScan:(NSDictionary*) scanInfo
{
    return [self generateXnatPath:[scanInfo objectForKey:@"project"]
                       forSubject:[scanInfo objectForKey:@"subject"]
                       forSession:[scanInfo objectForKey:@"session"]
                          forScan:[scanInfo objectForKey:@"scan"]];
}

- (NSString*) generateXnatPathScan:(NSDictionary*) scanInfo forResource:(NSString*) resource
{
    return [self generateXnatPath:[scanInfo objectForKey:@"project"]
                       forSubject:[scanInfo objectForKey:@"subject"]
                       forSession:[scanInfo objectForKey:@"session"]
                          forScan:[scanInfo objectForKey:@"scan"]
                      forResource:resource];
}

- (NSString*) generateXnatPathScan:(NSDictionary*) scanInfo forResource:(NSString*) resource forFile:(NSString*) file
{
    return [self generateXnatPath:[scanInfo objectForKey:@"project"]
                       forSubject:[scanInfo objectForKey:@"subject"]
                       forSession:[scanInfo objectForKey:@"session"]
                          forScan:[scanInfo objectForKey:@"scan"]
                      forResource:resource
                          forFile:file];
}

/*
 Get xnatPath for assessor, if nil, all assessors
 */
-(NSString*) generateXnatPath:(NSString*) project
                   forSubject:(NSString*) subject
                   forSession:(NSString*) session
                  forAssessor:(NSString*) assessor
{
    NSString* path = [[self generateXnatPath:project forSubject:subject forSession:session] stringByAppendingString:@"/assessors"];
    return [utils addToPath:path string:assessor];
}

/*
 Get xnatPath for out_resource for an assessor, if nil, all out_resources
 */
-(NSString*) generateXnatPath:(NSString*) project
                   forSubject:(NSString*) subject
                   forSession:(NSString*) session
                  forAssessor:(NSString*) assessor
                  forResource:(NSString*) resource
{
    NSString* path = [[self generateXnatPath:project forSubject:subject forSession:session forAssessor:assessor]
                      stringByAppendingString:@"/out/resources"];
    return [utils addToPath:path string:resource];
}

/*
 Get xnatPath for file on an out_resource for an assessor, if nil, all files
 */
-(NSString*) generateXnatPath:(NSString*) project
                   forSubject:(NSString*) subject
                   forSession:(NSString*) session
                  forAssessor:(NSString*) assessor
                  forResource:(NSString*) resource
                      forFile:(NSString*) file
{
    NSString* path = [[self generateXnatPath:project forSubject:subject forSession:session forAssessor:assessor forResource:resource]
                      stringByAppendingString:@"/files"];
    return [utils addToPath:path string:file];
}

/*
 Get xnatPath for assessor and resources and files by giving only the assessor label
 */
- (NSString*) generateXnatPathAssessor:(NSString*) assessor
{
    NSDictionary* xnatInfo = [self extractInfoFromAssessor:assessor];
    if(!xnatInfo)
        return @"";
    return [self generateXnatPath:[xnatInfo objectForKey:@"project"]
                       forSubject:[xnatInfo objectForKey:@"subject"]
                       forSession:[xnatInfo objectForKey:@"session"]
                      forAssessor:assessor];
}

- (NSString*) generateXnatPathAssessor:(NSString*) assessor forResource:(NSString*) resource
{
    NSDictionary* xnatInfo = [self extractInfoFromAssessor:assessor];
    if(!xnatInfo)
        return @"";
    return [self generateXnatPath:[xnatInfo objectForKey:@"project"]
                       forSubject:[xnatInfo objectForKey:@"subject"]
                       forSession:[xnatInfo objectForKey:@"session"]
                      forAssessor:assessor
                      forResource:resource];
}

- (NSString*) generateXnatPathAssessor:(NSString*) assessor forResource:(NSString*) resource forFile:(NSString*) file
{
    NSDictionary* xnatInfo = [self extractInfoFromAssessor:assessor];
    if(!xnatInfo)
        return @"";
    return [self generateXnatPath:[xnatInfo objectForKey:@"project"]
                       forSubject:[xnatInfo objectForKey:@"subject"]
                       forSession:[xnatInfo objectForKey:@"session"]
                      forAssessor:assessor
                      forResource:resource
                          forFile:file];
}

/*
 Get Assessor Label
 */
-(NSString*) getAssessorLabel:(NSString*) project
                   forSubject:(NSString*) subject
                   forSession:(NSString*) session
                      forScan:(NSString*) scan
                  forProctype:(NSString*) procType
{
    if(scan)
        return [NSString stringWithFormat:@"%@-x-%@-x-%@-x-%@-x-%@", project, subject, session, scan, procType];
    else
        return [NSString stringWithFormat:@"%@-x-%@-x-%@-x-%@", project, subject, session, procType];
}

-(NSString*) getOsiriXAssessorLabel:(NSString*) project forSubject:(NSString*) subject forSession:(NSString*) session
{
    return [NSString stringWithFormat:@"%@-x-%@-x-%@-x-OsiriX", project, subject, session];
}

-(NSString*) getAssessorLabel:(NSString*) project
                   forSubject:(NSString*) subject
                   forSession:(NSString*) session
                      forScan:(NSString*) scan
                  forProcName:(NSString*) procName
                  withVersion:(NSString*) version
                   withSuffix:(NSString*) suffix
{
    NSString * procType = [self generateProcType:procName withVersion:version withSuffix:suffix];
    if(scan)
        return [NSString stringWithFormat:@"%@-x-%@-x-%@-x-%@-x-%@", project, subject, session, scan, procType];
    else
        return [NSString stringWithFormat:@"%@-x-%@-x-%@-x-%@", project, subject, session, procType];
}

-(NSString*) generateProcType:(NSString*)procName withVersion:(NSString*)version withSuffix:(NSString*)suffix
{
    NSString* procType = procName;
    //Version
    procType = [procType stringByAppendingString:@"_v"];
    procType = [procType stringByAppendingString:[[version componentsSeparatedByString:@"."] objectAtIndex:0]];
    //Suffix
    if(suffix != nil && ![suffix isEqual:@""])
    {
        //Replace any specific character by _
        NSRegularExpression* regex = [NSRegularExpression
                                      regularExpressionWithPattern:@"[^a-zA-Z0-9]"
                                      options:0
                                      error:nil];
        suffix = [regex stringByReplacingMatchesInString:suffix options:0 range:NSMakeRange(0, [suffix length]) withTemplate:@"_"];
        if([suffix hasPrefix:@"_"])
            suffix = [suffix substringFromIndex:1];
        procType = [procType stringByAppendingString:@"_"];
        procType = [procType stringByAppendingString:suffix];
    }
    return procType;
}

-(NSDictionary*) extractInfoFromAssessor:(NSString*) assessor
{
    // String:
    NSMutableDictionary* xnatInformation = [[[NSMutableDictionary alloc] init] autorelease];
    NSArray* labels = [assessor componentsSeparatedByString:@"-x-"];
    if([labels count]<4)
    {
        [utils displayAlert:@"ERROR: Assessor label for XNAT not supported. Not enough arguments"];
        xnatInformation = nil;
    }
    else{
        [xnatInformation setObject:[labels objectAtIndex:0] forKey:@"project"];
        [xnatInformation setObject:[labels objectAtIndex:1] forKey:@"subject"];
        [xnatInformation setObject:[labels objectAtIndex:2] forKey:@"session"];
        [xnatInformation setObject:[labels lastObject] forKey:@"proctype"];
    }
    return xnatInformation;
}

/* Methods to check if an object exist */
- (BOOL) objectExistsOnXnat:(NSDictionary*) objInfo
{
    if(([[objInfo valueForKey:@"project"] length] == 0) || \
       ([[objInfo valueForKey:@"subject"] length] == 0) || \
       ([[objInfo valueForKey:@"session"] length] == 0))
        return false;
    
    // URL
    NSString* xnatPath = @"";
    if ([[objInfo valueForKey:@"scan"] length] > 0){
        xnatPath = [self generateXnatPathScan:objInfo forResource:nil];
    }else if ([[objInfo valueForKey:@"assessor"] length] > 0){
        xnatPath = [self generateXnatPathAssessor:[objInfo valueForKey:@"assessor"] forResource:nil];
    }else
        return false;

    NSURL *url = [NSURL URLWithString: [self generateXnatUrl:xnatPath withSuffix:@"?format=json"]];
    [self getRequest:url withBody:nil withContentType:@"application/json"];
    
    NSError *jsonParsingError = nil;
    id json = [NSJSONSerialization JSONObjectWithData:self.buffer options:0 error:&jsonParsingError];
    [self.buffer release]; // release the buffer after getting its content
    if (json) {
        id data = [[json objectForKey:@"ResultSet"] objectForKey:@"Result"];
        if([[data valueForKey:@"label"] count]>0)
            return true;
        else
            return false;
    }
    else
        return false;
}

/*
 Return Datatypes from XNAT
 */
- (NSArray*) datatypesXnat
{
    NSURL *url = [NSURL URLWithString: [self generateXnatUrl:@"search/elements" withSuffix:@"?format=json"]];
    [self getRequest:url withBody:nil withContentType:@"application/json"];
    // Extract JSON information and return it
    NSError *jsonParsingError = nil;
    id json = [NSJSONSerialization JSONObjectWithData:self.buffer options:0 error:&jsonParsingError];
    if (jsonParsingError) {
        NSLog(@"Error with json du to connection to XNAT (no data for arguments or wrong logins): %@",[jsonParsingError localizedDescription]);
        return nil;
    } else
        return [[json objectForKey:@"ResultSet"] objectForKey:@"Result"];
}

-(BOOL) hasDAXdatatypes
{
    if([[[self datatypesXnat] valueForKey:@"ELEMENT_NAME"] containsObject:@"proc:genProcData"])
        return true;
    else
        return false;
}

/* List of NSArray from XNAT for each object*/
- (id) listForXnatPath:(NSString*) xnatPath urlSuffix:(NSString*) urlSuffix sortBy:(NSString*) sortedKey
{
    NSURL *url = [NSURL URLWithString: [self generateXnatUrl:xnatPath withSuffix:urlSuffix]];
    [self getRequest:url withBody: nil withContentType:@"application/json"];
    // Extract JSON information and return it
    NSError *jsonParsingError = nil;
    id json = [NSJSONSerialization JSONObjectWithData:self.buffer options:0 error:&jsonParsingError];
    [self.buffer release]; // release the buffer after getting its content
    if (jsonParsingError) {
        NSLog(@"Error with json du to connection to XNAT (no data for arguments or wrong logins): %@",[jsonParsingError localizedDescription]);
        return nil;
    } else {
        id data = [[json objectForKey:@"ResultSet"] objectForKey:@"Result"];
        if(sortedKey)
        {
            // Sorting data using the key label if found or ID if not:
            NSString* keyToSort = nil;
            if([self arrayOfDict:data hasKey:sortedKey])
                keyToSort = sortedKey;
            else if([self arrayOfDict:data hasKey:@"label"])
                keyToSort = @"label";
            else if ([self arrayOfDict:data hasKey:@"ID"])
                keyToSort = @"ID";
            
            if(keyToSort){
                NSSortDescriptor *descriptor = [[[NSSortDescriptor alloc] initWithKey:keyToSort
                                                                            ascending:YES
                                                                             selector:@selector(localizedStandardCompare:)]
                                                autorelease];
                return [data sortedArrayUsingDescriptors:[NSArray arrayWithObject:descriptor]];
            }
            else
                return data;
        }
        else //No sorting
            return data;
    }
}

- (NSArray*) listProjectsOwned
{
    id projectsOwned = [self listForXnatPath:[self generateXnatPath:nil] urlSuffix:@"?format=json&owner=true&member=true&collaborator=true" sortBy:@"label"];
    return [projectsOwned valueForKey:@"id"];
}

- (id) listProjects;
{
    return [self listForXnatPath:[self generateXnatPath:nil] urlSuffix:@"?format=json" sortBy:@"label"];
}

- (id) listSubjectsForProject:(NSString*) project
{
    return [self listForXnatPath:[self generateXnatPath:project forSubject:nil] urlSuffix:@"?format=json" sortBy:@"label"];
}

- (id) listSessionsForProject:(NSString*) project andSubject:(NSString*) subject
{
    return [self listForXnatPath:[self generateXnatPath:project forSubject:subject forSession:nil] urlSuffix:@"?format=json" sortBy:@"label"];
}

- (id) listScansForProject:(NSString*) project
{
    NSString* xnatPath = @"experiments";
    NSString* urlSuffix = [NSString stringWithFormat:@"?project=%@&xsiType=xnat:imageSessionData&columns=project,subject_label,label,xnat:imagescandata/id,xnat:imagescandata/type,xnat:imagescandata/series_description,xnat:imagescandata/quality&format=json", project];
    return [self listForXnatPath:xnatPath urlSuffix:urlSuffix sortBy:@"subject_label"];
}

- (id) listScansForProjectWithResource:(NSString*) project
{
    NSString* xnatPath = @"experiments";
    NSString* urlSuffix = [NSString stringWithFormat:@"?project=%@&xsiType=xnat:imageSessionData&columns=project,subject_label,label,xnat:imagescandata/id,xnat:imagescandata/type,xnat:imagescandata/series_description,xnat:imagescandata/quality,xnat:imagescandata/file/label&format=json", project];
    NSMutableArray* data = [[[NSMutableArray alloc] init] autorelease];
    NSMutableArray* scansData = [[[NSMutableArray alloc] init] autorelease];
    data = [self listForXnatPath:xnatPath urlSuffix:urlSuffix sortBy:@"subject_label"];
    // Get all the scans with OsiriX resource:
    NSArray* scans = [utils filterListOfDictionaries:data
                                       forAttributes:@{@"xnat:imagescandata/file/label": @"DICOM"}];
    NSArray* osirixScans = [utils filterListOfDictionaries:data
                                             forAttributes:@{@"xnat:imagescandata/file/label": @"OsiriX"}];
    // Check the scans and the resources
    for(id scan in scans)
    {
        NSMutableDictionary* new_scan = [scan mutableCopy];
        [new_scan removeObjectForKey:@"xnat:imagescandata/file/label"];
        NSArray* foundScans = [utils filterListOfDictionaries:osirixScans
                                                forAttributes:@{@"label": [new_scan objectForKey:@"label"],
                                                                @"xnat:imagescandata/id": [new_scan objectForKey:@"xnat:imagescandata/id"]}];
        if ([foundScans count] > 0)
            [new_scan setValue:@"yes" forKey:@"resource"];
        else
            [new_scan setValue:@"no" forKey:@"resource"];
        [scansData addObject:new_scan];
    }
    return scansData;
}

- (id) listScansForProject:(NSString*) project andSubject:(NSString*) subject andSession:(NSString*) session
{
    return [self listForXnatPath:[self generateXnatPath:project forSubject:subject forSession:session forScan:nil] urlSuffix:@"?format=json" sortBy:@"ID"];
}

- (id) listScansForProject:(NSString*) project andSubject:(NSString*) subject andSession:(NSString*) session andType:(NSString*) types
{
    NSMutableArray* scans = [[[NSMutableArray alloc] init] autorelease];
    NSArray* typesList = [types componentsSeparatedByString:@","];
    NSArray* scansList = [self listScansForProject:project andSubject:subject andSession:session];
    for(id scan in scansList)
    {
        if([typesList containsObject:[scan valueForKey:@"type"]])
            [scans addObject:scan];
    }
    return scans;
}

- (id) listResourcesForProject:(NSString*) project andSubject:(NSString*) subject andSession:(NSString*) session andScan:(NSString*) scan
{
    return [self listForXnatPath:[self generateXnatPath:project forSubject:subject forSession:session forScan:scan forResource:nil]
                       urlSuffix:@"?format=json" sortBy:@"label"];
}

- (id) listFilesForProject:(NSString*) project
                andSubject:(NSString*) subject
                andSession:(NSString*) session
                   andScan:(NSString*) scan
               andResource:(NSString*) resource
{
    return [self listForXnatPath:[self generateXnatPath:project
                                             forSubject:subject
                                             forSession:session
                                                forScan:scan
                                            forResource:resource
                                                forFile:nil]
                       urlSuffix:@"?format=json" sortBy:@"Name"];
}

- (id) listAssessorsForProject:(NSString*) project
{
    NSString* xnatPath = @"experiments";
    NSString* urlSuffix = [NSString stringWithFormat:@"?project=%@&xsiType=proc:genprocdata&columns=ID,label,URI,xsiType,project,xnat:imagesessiondata/subject_id,xnat:imagesessiondata/id,xnat:imagesessiondata/label,proc:genprocdata/procstatus,proc:genprocdata/proctype,proc:genprocdata/validation/status,proc:genprocdata/validation/notes,proc:genprocdata/validation/method&format=json", project];
    return [self listForXnatPath:xnatPath urlSuffix:urlSuffix sortBy:@"subject_label"];
}

- (id) listAssessorsForProjectWithResource:(NSString*) project
{
    NSString* xnatPath = @"experiments";
    NSString* urlSuffix = [NSString stringWithFormat:@"?project=%@&xsiType=proc:genprocdata&columns=ID,label,URI,xsiType,project,xnat:imagesessiondata/subject_id,xnat:imagesessiondata/id,xnat:imagesessiondata/label,proc:genprocdata/procstatus,proc:genprocdata/proctype,proc:genprocdata/validation/status,proc:genprocdata/validation/notes,proc:genprocdata/validation/method,proc:genprocdata/out/file/label&format=json", project];
    NSMutableArray* assessorsData = [[[NSMutableArray alloc] init] autorelease];
    NSMutableArray* data = [[[NSMutableArray alloc] init] autorelease];
    data = [self listForXnatPath:xnatPath urlSuffix:urlSuffix sortBy:@"label"];
    // Get all the scans with OsiriX resource:
    NSArray* assessors = [utils filterListOfDictionaries:data
                                           forAttributes:@{@"proc:genprocdata/out/file/label": @"PBS"}];
    NSArray* osirixAssessors = [utils filterListOfDictionaries:data
                                                 forAttributes:@{@"proc:genprocdata/out/file/label": @"OsiriX"}];
    // Check the scans and the resources
    for(id assessor in assessors)
    {
        NSMutableDictionary* new_asse = [assessor mutableCopy];
        [new_asse removeObjectForKey:@"proc:genprocdata/out/file/label"];
        NSString* subject = [[[new_asse objectForKey:@"label"] componentsSeparatedByString:@"-x-"] objectAtIndex:1];
        [new_asse setValue:subject forKey:@"subject_label"];
        NSArray* foundAssessors = [utils filterListOfDictionaries:osirixAssessors
                                                    forAttributes:@{@"label": [new_asse objectForKey:@"label"]}];
        if ([foundAssessors count] > 0)
            [new_asse setValue:@"yes" forKey:@"resource"];
        else
            [new_asse setValue:@"no" forKey:@"resource"];
        [assessorsData addObject:new_asse];
    }
    return assessorsData;
}

- (id) listAssessorsForProject:(NSString*) project andSubject:(NSString*) subject andSession:(NSString*) session
{
    return [self listForXnatPath:[self generateXnatPath:project
                                             forSubject:subject
                                             forSession:session
                                            forAssessor:nil]
                       urlSuffix:@"?format=json" sortBy:@"label"];
}

- (id) listOutResourcesForProject:(NSString*) project
                       andSubject:(NSString*) subject
                       andSession:(NSString*) session
                      andAssessor:(NSString*) assessor
{
    return [self listForXnatPath:[self generateXnatPath:project
                                             forSubject:subject
                                             forSession:session
                                            forAssessor:assessor
                                            forResource:nil]
                       urlSuffix:@"?format=json" sortBy:@"label"];
}

- (id) listOutFilesForProject:(NSString*) project
                   andSubject:(NSString*) subject
                   andSession:(NSString*) session
                  andAssessor:(NSString*) assessor
                  andResource:(NSString*) resource
{
    return [self listForXnatPath:[self generateXnatPath:project
                                             forSubject:subject
                                             forSession:session
                                            forAssessor:assessor
                                            forResource:resource
                                                forFile:nil]
                       urlSuffix:@"?format=json" sortBy:@"Name"];
}

- (id) listFilesForAssessor:(NSString*) assessor andResource:(NSString*) resource
{
    return [self listForXnatPath:[self generateXnatPathAssessor:assessor forResource:resource forFile:nil]
                       urlSuffix:@"?format=json" sortBy:@"Name"];
}


/* Methods related to XNAT */
- (NSArray*) downloadFromScan:(NSString*) project
                   forSubject:(NSString*) subject
                   forSession:(NSString*) session
                      forScan:(NSString*) scan
                  forResource:(NSString*) resource
{
    // Osirix plugin directory for XNAT data
    NSString* tempDirName = [NSString stringWithFormat:@"%@_%@_%@_%@_%@", self.databaseName, project, session, scan, resource];
    NSString* directory = [NSString stringWithFormat:@"%@/%@/", self.dataFolder, tempDirName];
    [utils createDirectory:directory removeContentIfExists:true];
    // URL
    NSString* xnatPath = [self generateXnatPath:project forSubject:subject forSession:session forScan:scan forResource:resource forFile:nil];
    NSURL *url = [NSURL URLWithString: [self generateXnatUrl:xnatPath withSuffix:@"?format=zip"]];
    // API Call to download
    return [self downloadURL:url toDirectory:directory];
}

- (NSString*) downloadFromScan:(NSString*) project
                    forSubject:(NSString*) subject
                    forSession:(NSString*) session
                       forScan:(NSString*) scan
                   forResource:(NSString*) resource
                       forFile:(NSString*) file
{
    // Osirix plugin directory for XNAT data
    NSString* tempDirName = [NSString stringWithFormat:@"%@_%@_%@_%@_%@", self.databaseName, project, session, scan, resource];
    NSString* directory = [NSString stringWithFormat:@"%@/%@", self.dataFolder, tempDirName];
    [utils createDirectory:directory removeContentIfExists:true];
    NSString* filePath = [NSString stringWithFormat:@"%@/%@", directory, file];
    // URL
    NSString* xnatPath = [self generateXnatPath:project forSubject:subject forSession:session forScan:scan forResource:resource forFile:file];
    NSURL *url = [NSURL URLWithString: [self generateXnatUrl:xnatPath withSuffix:@""]];
    // API Call to download
    if([self downloadURL:url toFile:filePath])
        return filePath;
    else
        return nil;
}

- (NSArray*) downloadFromAssessor:(NSString*) assessor
                       forResource:(NSString*) resource
{
    if([self resourceExistsforAssessor:assessor forResource:resource])
    {
        // Osirix plugin directory for XNAT data
        NSString* tempDirName = [NSString stringWithFormat:@"%@_%@_%@", self.databaseName, assessor, resource];
        NSString* directory = [NSString stringWithFormat:@"%@/%@/", self.dataFolder, tempDirName];
        [utils createDirectory:directory removeContentIfExists:true];
        // URL
        NSString* xnatPath = [self generateXnatPathAssessor:assessor forResource:resource];
        NSURL *url = [NSURL URLWithString: [self generateXnatUrl:xnatPath withSuffix:@"/files?format=zip"]];
        // API Call to download
        return [self downloadURL:url toDirectory:directory];
    }
    else
        return nil;
}

- (BOOL) resourceExistsforAssessor:(NSString*) assessor forResource:(NSString*) resource
{
    NSDictionary* xnatInfo = [self extractInfoFromAssessor: assessor];
    NSArray* resources = [self listOutResourcesForProject:[xnatInfo valueForKey:@"project"]
                                               andSubject:[xnatInfo valueForKey:@"subject"]
                                               andSession:[xnatInfo valueForKey:@"session"]
                                              andAssessor:assessor];
    return [[resources valueForKey:@"label"] containsObject:resource];
}

- (NSString*) downloadFromAssessor:(NSString*) assessor
                       forResource:(NSString*) resource
                           forFile:(NSString*) file
{
    if([self fileExistsforAssessor:assessor forResource:resource forFile:file])
    {
        // Osirix plugin directory for XNAT data
        NSString* tempDirName = [NSString stringWithFormat:@"%@_%@_%@", databaseName, assessor, resource];
        NSString* directory = [NSString stringWithFormat:@"%@/%@/", self.dataFolder, tempDirName];
        [utils createDirectory:directory removeContentIfExists:true];
        NSString* filePath = [NSString stringWithFormat:@"%@/%@", directory, file];
        // URL
        NSString* xnatPath = [self generateXnatPathAssessor:assessor forResource:resource forFile:file];
        NSURL *url = [NSURL URLWithString: [self generateXnatUrl:xnatPath withSuffix:@""]];
        // API Call to download
        return [self downloadURL:url toFile:filePath];
    }
    else
        return nil;
}

- (BOOL) fileExistsforScan:(NSDictionary *)scanInfo forResource:(NSString *)resource forFile:(NSString *)file
{
    NSArray* files = [self listFilesForProject:[scanInfo valueForKey:@"project"]
                                    andSubject:[scanInfo valueForKey:@"subject"]
                                    andSession:[scanInfo valueForKey:@"session"]
                                       andScan:[scanInfo valueForKey:@"scan"]
                                   andResource:resource];
    return [[files valueForKey:@"Name"] containsObject:file];
}

- (BOOL) fileExistsforAssessor:(NSString*) assessor forResource:(NSString*) resource forFile:(NSString*) file
{
    NSDictionary* xnatInfo = [self extractInfoFromAssessor: assessor];
    NSArray* files = [self listOutFilesForProject:[xnatInfo valueForKey:@"project"]
                                       andSubject:[xnatInfo valueForKey:@"subject"]
                                       andSession:[xnatInfo valueForKey:@"session"]
                                      andAssessor:assessor
                                      andResource:resource];
    return [[files valueForKey:@"Name"] containsObject:file];
}

- (void) uploadZipFile:(NSString*) zipPath
             toProject:(NSString*) project
             toSubject:(NSString*) subject
             toSession:(NSString*) session
                toScan:(NSString*) scan
            toResource:(NSString*) resource
{
    // Upload to scan
    NSDictionary* scanInfo = @{@"project":project, @"subject":subject, @"session":session, @"scan":scan};
    [self uploadZipFile:zipPath toScan:scanInfo toResource:resource];
}

- (void) uploadZipFile:(NSString*) zipPath
            toScan:(NSDictionary *)scanInfo
            toResource:(NSString *)resource
{
    // Upload to Assessor
    NSString* xnatPath = [self generateXnatPathScan:scanInfo
                                        forResource:resource
                                            forFile:[zipPath lastPathComponent]];
    [self uploadURL:[NSURL URLWithString:[self generateXnatUrl:xnatPath withSuffix:@"?extract=true"]] forFile:zipPath];
}

- (void) uploadZipFile:(NSString*) zipPath
             toProject:(NSString*) project
             toSubject:(NSString*) subject
             toSession:(NSString*) session
                toScan:(NSString*) scan
            toProcName:(NSString*) procName
           withVersion:(NSString*) version
            withSuffix:(NSString*) suffix
            toResource:(NSString*) resource
{
    // Upload to Assessor
    NSString* assessor = [self getAssessorLabel:project forSubject:subject forSession:session forScan:scan forProcName:procName withVersion:
                                version withSuffix:suffix];
    [self uploadZipFile:zipPath toAssessor:assessor toResource:resource];
}

- (void) uploadZipFile:(NSString*) zipPath
            toAssessor:(NSString*) assessor
            toResource:(NSString*) resource
{
    // Upload to Assessor
    NSString* xnatPath = [self generateXnatPathAssessor:assessor
                                            forResource:resource
                                                forFile:[zipPath lastPathComponent]];
    [self uploadURL:[NSURL URLWithString:[self generateXnatUrl:xnatPath withSuffix:@"?extract=true"]] forFile:zipPath];
}

- (void) uploadFile:(NSString*) filePath
          toProject:(NSString*) project
          toSubject:(NSString*) subject
          toSession:(NSString*) session
             toScan:(NSString*) scan
         toResource:(NSString*) resource
          overwrite:(BOOL) overwrite
{
    // Upload to scan
    NSDictionary* scanInfo = @{@"project":project, @"subject":subject, @"session":session, @"scan":scan};
    [self uploadFile:filePath toScan:scanInfo toResource:resource overwrite:overwrite];
}

- (void) uploadFile:(NSString*) filePath
             toScan:(NSDictionary*) scanInfo
         toResource:(NSString*) resource
          overwrite:(BOOL) overwrite
{
    // Upload to Assessor
    NSString* xnatPath = [self generateXnatPathScan:scanInfo
                                        forResource:resource
                                            forFile:[filePath lastPathComponent]];
    if(overwrite){
        NSLog(@"Overwriting the file on XNAT for %@ -- %@ -- %@ -- %@", [scanInfo valueForKey:@"session"],
              [scanInfo valueForKey:@"scan"], resource, [filePath lastPathComponent]);
        [self uploadURL:[NSURL URLWithString:[self generateXnatUrl:xnatPath withSuffix:@"?overwrite=true"]] forFile:filePath];
    }
    else{
        NSLog(@"Uploading the file on XNAT for %@ -- %@ -- %@ -- %@",[scanInfo valueForKey:@"session"],
              [scanInfo valueForKey:@"scan"], resource, [filePath lastPathComponent]);
        [self uploadURL:[NSURL URLWithString:[self generateXnatUrl:xnatPath withSuffix:@""]] forFile:filePath];
    }
}

- (void) uploadFile:(NSString*) filePath
          toProject:(NSString*) project
          toSubject:(NSString*) subject
          toSession:(NSString*) session
             toScan:(NSString*) scan
         toProcName:(NSString*) procName
        withVersion:(NSString*) version
         withSuffix:(NSString*) suffix
         toResource:(NSString*) resource
          overwrite:(BOOL) overwrite
{
    // Upload to Assessor
    NSString* assessor = [self getAssessorLabel:project forSubject:subject forSession:session forScan:scan forProcName:procName withVersion:
                          version withSuffix:suffix];
    [self uploadFile:filePath toAssessor:assessor toResource:resource overwrite:overwrite];
}

- (void) uploadFile:(NSString*) filePath
         toAssessor:(NSString*) assessor
         toResource:(NSString*) resource
          overwrite:(BOOL) overwrite
{
    // Upload to Assessor
    NSString* xnatPath = [self generateXnatPathAssessor:assessor
                                            forResource:resource
                                                forFile:[filePath lastPathComponent]];
    if(overwrite){
        NSLog(@"Overwriting the file on XNAT for %@ -- %@ -- %@",assessor, resource, [filePath lastPathComponent]);
        [self uploadURL:[NSURL URLWithString:[self generateXnatUrl:xnatPath withSuffix:@"?overwrite=true"]] forFile:filePath];
    }
    else{
        NSLog(@"Uploading the file on XNAT for %@ -- %@ -- %@",assessor, resource, [filePath lastPathComponent]);
        [self uploadURL:[NSURL URLWithString:[self generateXnatUrl:xnatPath withSuffix:@""]] forFile:filePath];
    }
}

- (void) uploadSnapshotsAssessor:(NSString*) assessor
{
    // Upload for new assessor the logo of OsiriX as SNAPSHOTS
    NSBundle* bundle = [NSBundle bundleForClass:[xnatRequest class]];
    NSString* snapshot = [bundle pathForResource:@"OsiriX.png" ofType:nil];
    NSString* snapshotPreview = [bundle pathForResource:@"OsiriX_preview.png" ofType:nil];
    NSString* xnatPath = [self generateXnatPathAssessor:assessor
                                            forResource:@"SNAPSHOTS"
                                                forFile:[snapshot lastPathComponent]];
    [self uploadURL:[NSURL URLWithString:[self generateXnatUrl:xnatPath withSuffix:@"?content=ORIGINAL&tags=U&format=PNG"]] forFile:snapshot];
    xnatPath = [self generateXnatPathAssessor:assessor
                                  forResource:@"SNAPSHOTS"
                                      forFile:[snapshotPreview lastPathComponent]];
    [self uploadURL:[NSURL URLWithString:[self generateXnatUrl:xnatPath withSuffix:@"?content=THUMBNAIL&tags=U&format=PNG"]] forFile:snapshotPreview];
}

- (void) createAssessor:(NSString*) assessor
            withVersion:(NSString*) version
             withStatus:(NSString*) qcstatus
{
    // Xnat Path
    NSString* xnatPath = [self generateXnatPathAssessor:assessor];
    // Date
    NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
    [dateFormatter setDateFormat:@"MM/dd/yy"];
    // URL
    NSString* urlSuffix = [NSString stringWithFormat:@"?xsiType=proc:genProcData&proc:genProcData/validation/status=%@&\
                           proc:genProcData/date=%@&proc:genProcData/proctype=%@&proc:genProcData/procstatus=COMPLETE&proc:genProcData/procversion=%@",
                           qcstatus, [dateFormatter stringFromDate:[NSDate date]], [[assessor componentsSeparatedByString:@"-x-"] lastObject], version];
    NSString* URLFormat = [self generateXnatUrl:xnatPath withSuffix:urlSuffix];
    NSURL *url = [NSURL URLWithString: URLFormat];
    // Run CURL command to grab data
    [self putRequest:url withBody:nil withContentType:nil];
    // Create resource SNAPSHOTS:
    url = [NSURL URLWithString: [self generateXnatUrl:[self generateXnatPathAssessor:assessor forResource:@"SNAPSHOTS"] withSuffix:@""]];
    [self putRequest:url withBody:nil withContentType:nil];
    // Upload Snapshots
    [self uploadSnapshotsAssessor:assessor];
}

- (void) createAssessorOnProject:(NSString*) project
                      forSubject:(NSString*) subject
                      forSession:(NSString*) session
                         forScan:(NSString*) scan
                        withProc:(NSString*) procName
                      withSuffix:(NSString*) suffix
                     withVersion:(NSString*) version
                      withStatus:(NSString*) qcstatus
{
    NSString* assessor = [self getAssessorLabel:project forSubject:subject forSession:session forScan:scan forProcName:procName withVersion:version withSuffix:suffix];
    [self createAssessor:assessor withVersion:version withStatus:qcstatus];
}

- (void) createDefaultOsirixOnProject:(NSString*) project
                           forSubject:(NSString*) subject
                           forSession:(NSString*) session
{
    NSString* assessor = [self getOsiriXAssessorLabel:project forSubject:subject forSession:session];
    [self createAssessor:assessor withVersion:@"1.0.0" withStatus:@"DoNotApply"];
}

- (void) editQCStatus:(NSString*) assessor
           withStatus:(NSString*) qcStatus
          usingMethod:(NSString*) method
            withNotes:(NSString*) notes
{
    // Xnat Path
    NSString* xnatPath = [self generateXnatPathAssessor:assessor];
    // Date
    NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
    [dateFormatter setDateFormat:@"yy-MM-dd"];
    // URL
    NSString* urlSuffix = [NSString stringWithFormat:@"?proc:genProcData/validation/status=%@&proc:genProcData/validation/method=%@&proc:genProcData/validation/date=%@&proc:genProcData/validation/notes=%@&proc:genProcData/validation/validated_by=%@",
                           qcStatus, method, [dateFormatter stringFromDate:[NSDate date]], notes, [self xnatUser]];
    NSString* URLFormat = [self generateXnatUrl:xnatPath withSuffix:urlSuffix];
    NSURL *url = [NSURL URLWithString: URLFormat];
    // Run CURL command to grab data
    [self putRequest:url withBody:nil withContentType:nil];
}

- (BOOL) assessorExists:(NSString*) assessor
{
    NSDictionary* xnatInfo = [self extractInfoFromAssessor:assessor];
    if(!xnatInfo)
        return false;
    NSArray* assessors = [self listAssessorsForProject:[xnatInfo objectForKey:@"project"]
                                            andSubject:[xnatInfo objectForKey:@"subject"]
                                            andSession:[xnatInfo objectForKey:@"session"]];
    return [[assessors valueForKey:@"label"] containsObject: assessor];
}

- (BOOL) assessorExists:(NSString*) project
             forSubject:(NSString*) subject
             forSession:(NSString*) session
                forScan:(NSString*) scan
           withProcName:(NSString*) procName
             withSuffix:(NSString*) suffix
            withVersion:(NSString*) version
{
    NSString* assessor = [self getAssessorLabel:project forSubject:subject forSession:session forScan:scan forProcName:procName withVersion:version withSuffix:suffix];
    NSArray* assessors = [self listAssessorsForProject:project andSubject:subject andSession:session];
    return [[assessors valueForKey:@"label"] containsObject: assessor];
}

/* API calls all Synchronous */
- (NSString*) downloadURL:(NSURL*)url toFile:(NSString*) filePath
{
    // Download using get asynchronous
    [self getRequest:url withBody:nil withContentType:@"text/bin"];
    // Write the file from buffer to zip
    [self.buffer  writeToFile:filePath atomically:YES];
    [self.buffer release]; // release the buffer after getting its content
    // Check that file
    NSFileManager *fileManager= [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:filePath]){
        return filePath;
    }else{
        NSLog(@"DEBUG: The process to download the resource selected from XNAT failed.");
        return nil;
    }
}

- (NSArray*) downloadURL:(NSURL*)url toDirectory:(NSString*) directory
{
    // Download using get asynchronous
    [self getRequest:url withBody:nil withContentType:@"application/zip"];
    // Write the file from buffer to zip
    NSString* zipPath = [NSString stringWithFormat:@"%@/resource.zip", directory];
    [self.buffer  writeToFile:zipPath atomically:YES];
    [self.buffer release]; // release the buffer after getting its content
    // Check that resource.zip exist in the download folder and copy it to the directory and unzip it
    NSFileManager *fileManager= [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:zipPath]){
        // Unzip the file in the directory without subdir:
        NSString* unzipCommand = [NSString stringWithFormat:@"unzip -o -d %@ -j %@", directory, zipPath];
        [unzipCommand runAsCommand];
        [fileManager removeItemAtPath:zipPath error:nil];
        NSMutableArray* files = [utils listFilesInDirectory:directory];
        if([files count] == 1 && [[files objectAtIndex:0] hasSuffix:@".zip"])
        {
            zipPath = [files objectAtIndex:0];
            NSString* unzipCommand = [NSString stringWithFormat:@"unzip -o -d %@ -j %@", directory, zipPath];
            [unzipCommand runAsCommand];
            [fileManager removeItemAtPath:zipPath error:nil];
            files = [utils listFilesInDirectory:directory];
        }
        return files;
    }else{
        NSLog(@"DEBUG: The process to download the resource selected from XNAT failed.");
        return nil;
    }
}

- (void) uploadURL:(NSURL *)url forFile:(NSString *)filePath
{
    // Create header field for HTTP Request
    NSString *boundary = [self generateBoundaryString];
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    // Create body field for request
    NSData *httpBody = [self createBodyWithBoundary:boundary paths:@[filePath] fieldName:@"upload"];
    
    [self postRequest:url withBody:httpBody withContentType:contentType];
}

- (void) getRequest:(NSURL *)url withBody:(NSData*) httpBody withContentType:(NSString*) contentType
{
    // Init the buffer
    self.buffer = [[NSMutableData alloc]init];
    
    // Create request
    NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] initWithURL:url] autorelease];
    [request setValue:@"application/json" forHTTPHeaderField:@"accept"];
    [request setValue:contentType forHTTPHeaderField:@"Content-Type"];
    // Set body if needed
    if(httpBody)
        [request setHTTPBody:httpBody];
    // Set authentification:
    [request setValue:[NSString stringWithFormat:@"Basic %@", [self getAuthentification]] forHTTPHeaderField:@"Authorization"];
    
    //if there is a connection going on just cancel it.
    [self.connection cancel];
    
    //initialize a request from url
    NSURLResponse *response = [[[NSURLResponse alloc] init] autorelease];
    
    [self.buffer appendData:[NSURLConnection sendSynchronousRequest:request returningResponse:&response error:nil]];
}

- (void) postRequest:(NSURL *)url withBody:(NSData*) httpBody withContentType:(NSString*) contentType
{
    // Create request
    NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] initWithURL:url] autorelease];
    // Set method
    [request setHTTPMethod:@"POST"];
    // Create header field for HTTP Request
    [request setValue:contentType forHTTPHeaderField: @"Content-Type"];
    // Set body
    [request setHTTPBody:httpBody];
    // Set authentification:
    [request setValue:[NSString stringWithFormat:@"Basic %@", [self getAuthentification]] forHTTPHeaderField:@"Authorization"];
    // Call request
    NSURLResponse *response = [[[NSURLResponse alloc] init] autorelease];
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:nil];
}

- (void) putRequest:(NSURL *)url withBody:(NSData*) httpBody withContentType:(NSString*) contentType
{
    // Create request
    NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] initWithURL:url] autorelease];
    // Set method
    [request setHTTPMethod:@"PUT"];
    // Create header field for HTTP Request
    if(contentType)
        [request setValue:contentType forHTTPHeaderField: @"Content-Type"];
    // Set body
    if(httpBody)
        [request setHTTPBody:httpBody];
    // Set authentification:
    [request setValue:[NSString stringWithFormat:@"Basic %@", [self getAuthentification]] forHTTPHeaderField:@"Authorization"];
    // Call request
    NSURLResponse *response = [[[NSURLResponse alloc] init] autorelease];
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:nil];
}

@end
