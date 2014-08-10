//
//  BAMAppDelegate.h
//  Instaplay
//
//  Created by Scott Wilson on 8/7/14.
//  Copyright (c) 2014 Scott Wilson. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class BAMQueueController;

@interface BAMAppDelegate : NSObject <NSApplicationDelegate>
{
    IBOutlet BAMQueueController *queueController;
}

@property (assign) IBOutlet NSWindow *window;

@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@property (readonly, strong, nonatomic) BAMQueueController *queueController;
@property (strong, nonatomic) NSURL *outputURL;

- (IBAction)saveAction:(id)sender;
- (IBAction)selectOutputPath:(id)sender;
- (NSURL *)applicationFilesDirectory;

@end
