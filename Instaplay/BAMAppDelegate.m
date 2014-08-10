//
//  BAMAppDelegate.m
//  Instaplay
//
//  Created by Scott Wilson on 8/7/14.
//  Copyright (c) 2014 Scott Wilson. All rights reserved.
//

#import "BAMAppDelegate.h"
#import "BAMQueueController.h"
#import "BAMOptimizeOperation.h"


BOOL fileURLsAreEqual(NSURL *url1, NSURL *url2);

@implementation BAMAppDelegate

@synthesize window = _window;
@synthesize persistentStoreCoordinator = __persistentStoreCoordinator;
@synthesize managedObjectModel = __managedObjectModel;
@synthesize managedObjectContext = __managedObjectContext;
@synthesize queueController;


- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{
    return YES;
    
}

- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
    [self.queueController queueFilenames: filenames];
    
    //    for (NSString *filename in filenames) {
    //        NSLog(@"creating operation for: %@", filename);
    //        NSURL *fileURL = [NSURL fileURLWithPath:filename];
    //        BAMOptimizeOperation *oo = [BAMOptimizeOperation createOptimizeOperationFromURL:fileURL];
    //        [[NSOperationQueue mainQueue] addOperation: oo];
    //    }
    
    //    NSFileManager *fm = [NSFileManager defaultManager];
    //    NSLog(@"filenames: %@", filenames);
    //    for (NSString *filename in filenames) {
    //        NSURL *fileURL = [NSURL fileURLWithPath:filename];
    //        NSString *outFilePath = [filename stringByAppendingPathExtension: @"tmp"];
    //        NSURL *outFileURL = [NSURL fileURLWithPath: outFilePath];
    //        NSString *originalPath = [filename stringByAppendingPathExtension: @"orig"];
    //        NSURL *originalURL = [NSURL fileURLWithPath: originalPath];
    //
    //        BAMOptimizeOperation *oo = [BAMOptimizeOperation optimizeOperationFromURL: fileURL];
    //        [oo readTopLevelAtoms];
    //        if([oo writeOptimizedFileToURL: outFileURL]){
    //            [fm moveItemAtURL:fileURL toURL:originalURL error:NULL];
    //            [fm moveItemAtURL:outFileURL toURL:fileURL error:NULL];
    //        }
    //    }
}



- (BOOL)application:(id)sender openFileWithoutUI:(NSString *)filename
{
    return YES;
}

- (IBAction)openOutputFolderInFinder:(id)sender
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *movieURL = [[fileManager URLsForDirectory:NSMoviesDirectory inDomains:NSUserDomainMask] objectAtIndex:0];
    NSURL *defaultOutputPath = [movieURL URLByAppendingPathComponent:@"Instaplay"];
    
    if(!fileURLsAreEqual(defaultOutputPath, self.outputURL)){
        [[NSWorkspace sharedWorkspace] openFile:[self.outputURL path] withApplication:@"Finder"];
    }else{
        [[NSWorkspace sharedWorkspace] openFile:[movieURL path] withApplication:@"Finder"];
    }
}

- (IBAction)selectOutputPath:(id)sender
{
    //[[NSUserDefaults standardUserDefaults] registerDefaults:userDefaultsValuesDict];
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setCanChooseFiles:NO];
    [openPanel setAllowsMultipleSelection:NO];
    if([openPanel runModal] == NSFileHandlingPanelOKButton){
        NSLog(@"openPanel: %@", [openPanel URLs]);
        self.outputURL = [[openPanel URLs] objectAtIndex:0];
    };
}

- (void)setOutputURL:(NSURL *)outputURL
{
    //    if(_outputURL){
    //        [_outputURL stopAccessingSecurityScopedResource];
    //    }
    _outputURL = outputURL;
    NSLog(@"startAccessingSecurityScopedResource: %@", self.outputURL);
    NSURLBookmarkCreationOptions options = 0; // NSURLBookmarkCreationWithSecurityScope
    NSData *outputBookmark = [self.outputURL bookmarkDataWithOptions: options
                                      includingResourceValuesForKeys: nil
                                                       relativeToURL: nil
                                                               error: nil];
    [[NSUserDefaults standardUserDefaults] setObject:outputBookmark forKey:@"outputBookmark"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSData *outputDirectoryBookmark = [[NSUserDefaults standardUserDefaults] dataForKey:@"outputBookmark"];
    NSURL *outputDirectoryURL = nil;
    if(outputDirectoryBookmark == nil){
        NSURL *appSupportURL = [[fileManager URLsForDirectory:NSMoviesDirectory inDomains:NSUserDomainMask] objectAtIndex:0];
        outputDirectoryURL = [appSupportURL URLByAppendingPathComponent:@"Instaplay"];
    }else{
        BOOL isStale;
        BOOL sandbox = NO;
        if(sandbox){
            outputDirectoryURL = [NSURL URLByResolvingBookmarkData:outputDirectoryBookmark options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil bookmarkDataIsStale:&isStale error:nil];
            [outputDirectoryURL startAccessingSecurityScopedResource];
        }else{
            outputDirectoryURL = [NSURL URLByResolvingBookmarkData:outputDirectoryBookmark options:0 relativeToURL:nil bookmarkDataIsStale:&isStale error:nil];
        }
        
    }
    [fileManager createDirectoryAtURL:outputDirectoryURL withIntermediateDirectories:YES attributes:nil error:nil];
    self.outputURL = outputDirectoryURL;
    
    if(outputDirectoryBookmark == nil){
       NSFileManager *fileManager = [NSFileManager defaultManager];
       NSURL *appSupportURL = [[fileManager URLsForDirectory:NSMoviesDirectory inDomains:NSUserDomainMask] objectAtIndex:0];

       NSLog(@"%@", appSupportURL);

       self.outputURL = [appSupportURL URLByAppendingPathComponent:@"Instaplay"];
       [self.outputURL bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
                includingResourceValuesForKeys:nil relativeToURL:nil error:nil];
    }
}

// Returns the directory the application uses to store the Core Data store file. This code uses a directory named "stw.Video_Optimizer" in the user's Application Support directory.
- (NSURL *)applicationFilesDirectory
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *appSupportURL = [[fileManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] objectAtIndex:0];
    return [appSupportURL URLByAppendingPathComponent:@"com.bamenan.instaplay"];
}

// Creates if necessary and returns the managed object model for the application.
- (NSManagedObjectModel *)managedObjectModel
{
    if (__managedObjectModel) {
        return __managedObjectModel;
    }
	
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Instaplay" withExtension:@"momd"];
    __managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return __managedObjectModel;
}

// Returns the persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. (The directory for the store is created, if necessary.)
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (__persistentStoreCoordinator) {
        return __persistentStoreCoordinator;
    }
    
    NSManagedObjectModel *mom = [self managedObjectModel];
    if (!mom) {
        NSLog(@"%@:%@ No model to generate a store from", [self class], NSStringFromSelector(_cmd));
        return nil;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *applicationFilesDirectory = [self applicationFilesDirectory];
    NSError *error = nil;
    
    NSDictionary *properties = [applicationFilesDirectory resourceValuesForKeys:[NSArray arrayWithObject:NSURLIsDirectoryKey] error:&error];
    
    if (!properties) {
        BOOL ok = NO;
        if ([error code] == NSFileReadNoSuchFileError) {
            ok = [fileManager createDirectoryAtPath:[applicationFilesDirectory path] withIntermediateDirectories:YES attributes:nil error:&error];
        }
        if (!ok) {
            [[NSApplication sharedApplication] presentError:error];
            return nil;
        }
    } else {
        if (![[properties objectForKey:NSURLIsDirectoryKey] boolValue]) {
            // Customize and localize this error.
            NSString *failureDescription = [NSString stringWithFormat:@"Expected a folder to store application data, found a file (%@).", [applicationFilesDirectory path]];
            
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            [dict setValue:failureDescription forKey:NSLocalizedDescriptionKey];
            error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:101 userInfo:dict];
            
            [[NSApplication sharedApplication] presentError:error];
            return nil;
        }
    }
    
    NSURL *url = [applicationFilesDirectory URLByAppendingPathComponent:@"Video_Optimizer.storedata"];
    NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
    if (![coordinator addPersistentStoreWithType:NSXMLStoreType configuration:nil URL:url options:nil error:&error]) {
        [[NSApplication sharedApplication] presentError:error];
        return nil;
    }
    __persistentStoreCoordinator = coordinator;
    
    return __persistentStoreCoordinator;
}

// Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.)
- (NSManagedObjectContext *)managedObjectContext
{
    if (__managedObjectContext) {
        return __managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (!coordinator) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [dict setValue:@"Failed to initialize the store" forKey:NSLocalizedDescriptionKey];
        [dict setValue:@"There was an error building up the data file." forKey:NSLocalizedFailureReasonErrorKey];
        NSError *error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:9999 userInfo:dict];
        [[NSApplication sharedApplication] presentError:error];
        return nil;
    }
    __managedObjectContext = [[NSManagedObjectContext alloc] init];
    [__managedObjectContext setPersistentStoreCoordinator:coordinator];
    
    return __managedObjectContext;
}

// Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window
{
    return [[self managedObjectContext] undoManager];
}

// Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
- (IBAction)saveAction:(id)sender
{
    NSError *error = nil;
    
    if (![[self managedObjectContext] commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing before saving", [self class], NSStringFromSelector(_cmd));
    }
    
    if (![[self managedObjectContext] save:&error]) {
        [[NSApplication sharedApplication] presentError:error];
    }
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    // Save changes in the application's managed object context before the application terminates.
    
    if (!__managedObjectContext) {
        return NSTerminateNow;
    }
    
    if (![[self managedObjectContext] commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing to terminate", [self class], NSStringFromSelector(_cmd));
        return NSTerminateCancel;
    }
    
    [self.queueController cancelAllOperations];
    
    if (![[self managedObjectContext] hasChanges]) {
        return NSTerminateNow;
    }
    
    NSError *error = nil;
    if (![[self managedObjectContext] save:&error]) {
        
        // Customize this code block to include application-specific recovery steps.
        BOOL result = [sender presentError:error];
        if (result) {
            return NSTerminateCancel;
        }
        
        NSString *question = NSLocalizedString(@"Could not save changes while quitting. Quit anyway?", @"Quit without saves error question message");
        NSString *info = NSLocalizedString(@"Quitting now will lose any changes you have made since the last successful save", @"Quit without saves error question info");
        NSString *quitButton = NSLocalizedString(@"Quit anyway", @"Quit anyway button title");
        NSString *cancelButton = NSLocalizedString(@"Cancel", @"Cancel button title");
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:question];
        [alert setInformativeText:info];
        [alert addButtonWithTitle:quitButton];
        [alert addButtonWithTitle:cancelButton];
        
        NSInteger anBAMer = [alert runModal];
        
        if (anBAMer == NSAlertAlternateReturn) {
            return NSTerminateCancel;
        }
    }
    
    return NSTerminateNow;
}

@end
