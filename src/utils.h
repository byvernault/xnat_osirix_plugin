//
//  utils.h
//  XNAT
//
//  Created by Benjamin Yvernault on 16/10/2015.
//
//

#import <Foundation/Foundation.h>

@interface utils : NSObject

+ (void)displayAlert:(NSString*) value;
+ (void)displayMessage:(NSString*) message;
+ (BOOL)profileAlert:(NSString*) message;
+ (BOOL)overwriteAlert:(NSString*) message forAll:(BOOL*)forAll;
+ (BOOL)notSeeAnymoreTheAlert:(NSString*) message;
+ (NSMutableArray*)listFilesInDirectory:(NSString*) directory;
+ (void) setXnatInformation:(NSData *) data
                   forLabel:(NSString*) label
                    onLevel:(int) level
            fromPopUpButton:(NSPopUpButton*) fromButton
              onPopUpButton:(NSPopUpButton*) toButton;
+ (void) setXnatInformation:(NSData *) data
                   forLabel:(NSString*) label
                    onLevel:(int) level
              fromTextField:(NSTextField*) textField
              onPopUpButton:(NSPopUpButton*) toButton;
+ (void) resetTextField:(NSTextField*) textField;
+ (NSString*) messageForLevel:(int) level;
+ (void) resetPopUpButton:(NSPopUpButton*) button;
+ (void) clearButtons:(NSArray*) buttonArray;
+ (NSDictionary*) readInfoFromComment:(NSString*) comment;
+ (BOOL) isGoodVersion:(NSString*) version;
+ (BOOL) createDirectory:(NSString*) directory removeContentIfExists:(BOOL) remove;
+ (NSString*) addToPath:(NSString*) path string:(NSString*) str;
+ (NSArray*) getListImageSeries:(NSArray*) selection;
+ (NSArray*) getListROISeries:(NSArray*) selection;
+ (BOOL) isROISeries:(id) series;
+ (NSArray*) getDicomFilesForSeriesList:(NSArray*) seriesList;
+ (NSDictionary*) getDicomFilesForSeries:(id) series;
+ (void) zipFiles:(NSArray*) files asFilePath:(NSString*) zipPath;
+ (NSString *)getSubstring:(NSString *)value betweenString:(NSString *)separator1 andString:(NSString *)separator2;
+ (NSArray*) extractROIsFromSeries:(id) series;
+ (NSDictionary*) extractROIsNamedFromSeries:(id) series;
+ (NSString*) roiSave: (NSArray*) roiList inFile:(NSString *) filePath;
+ (NSArray*) roiLoad:(NSString *) filePath;
+ (BOOL) isROIListEmpty:(NSArray*) roiList;
+ (NSArray*) filterListOfDictionaries:(NSArray*) listDict forAttributes:(NSDictionary*) attributes;
+ (NSString*) errorAsString:(NSArray*) errorList forType:(NSString*)type;
+ (NSArray*) getScansListFromIDs:(NSString*) project
                      forSubject:(NSString*) subject
                      forSession:(NSString*) session
                     forScansIDs:(NSArray*) scans;
+ (BOOL) isProfileAlreadySaved:(NSArray*) profilesJSON forHost:(NSString*) host forUser:(NSString*) user;
+ (int) indexForProfile:(NSArray*) profilesJSON forHost:(NSString*) host forUser:(NSString*) user;
+ (NSDictionary*) getProfile:(NSArray*) profilesJSON forDataBase:(NSString*) database;
+ (NSArray*) databasesFromProfile:(NSDictionary*) profileJSON;
+ (NSString*) getDataFolderFromProfiles:(NSArray*) profilesJSON andDatabase:(NSString *) database;
+ (NSString*) getDataFolderFromProfile:(NSDictionary*) profileJSON andDatabase:(NSString *) database;
+ (void) removeROIFile:(NSString*) roiFile;
+ (NSString*) getDirectoryFolder;

@end

