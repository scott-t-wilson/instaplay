//
//  BAMQueueController.m
//  Instaplay
//
//  Created by Scott Wilson on 6/25/12.
//  Copyright (c) 2012 Scott Wilson. All rights reserved.
//

#import "BAMAppDelegate.h"
#import "BAMQueueController.h"
#import "BAMOptimizeOperation.h"
#import "BAMQueueItem.h"



@interface BAMQueueController()

@property (nonatomic) NSManagedObjectContext * moc;
@property (strong, nonatomic) NSEntityDescription * queueItemEntity;
@property (strong, nonatomic) NSMutableArray * operationQueue;

@end

@implementation BAMQueueController

@synthesize arrayController;
@synthesize tableView;
@synthesize moc = moc_;
@synthesize queueItemEntity = queueItemEntity_;
@synthesize operationQueue = operationQueue_;

- (void)awakeFromNib
{
    NSLog(@"BAMQueueController:awakeFromNib");
    
    BAMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    self.moc = appDelegate.managedObjectContext;
    self.queueItemEntity = [NSEntityDescription
                            entityForName:@"BAMQueueItem"
                            inManagedObjectContext:self.moc];
        
    [mainWindow registerForDraggedTypes: [NSArray arrayWithObjects:
                                          NSFilenamesPboardType,
                                          nil]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(operationNotification:) 
                                                 name:SWOperationNotification
                                               object:NULL];
    
//    [[NSNotificationCenter defaultCenter] addObserver:self 
//                                             selector:@selector(applicationWillTerminate:) 
//                                                 name:NSApplicationWillTerminateNotification 
//                                               object:nil]; 
    
    self.operationQueue = [NSMutableArray arrayWithCapacity: 32];
}




#pragma mark drag and drop handling

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {	
    NSPasteboard *pboard;
    NSDragOperation sourceDragMask;
    
    sourceDragMask = [sender draggingSourceOperationMask];
    pboard = [sender draggingPasteboard];
    if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
        if (sourceDragMask & (NSDragOperationGeneric)) {
            return NSDragOperationGeneric;
        } 
    }
    return NSDragOperationNone;
}


- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard;
    NSDragOperation sourceDragMask;

    sourceDragMask = [sender draggingSourceOperationMask];
    pboard = [sender draggingPasteboard];

    if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
        NSArray *filenames = [pboard propertyListForType:NSFilenamesPboardType];
        
        // Depending on the dragging source and modifier keys,
        // the file data may be copied or linked
        if (sourceDragMask & NSDragOperationGeneric) {
            NSLog(@"Optimize: %@", filenames);
            [self queueFilenames: filenames];
            return YES;
        }
    }
    return NO;
}

- (void)deleteAll
{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:self.queueItemEntity];
    
    NSError *error = nil;
    NSArray *array = [self.moc executeFetchRequest:request error:&error];
    for(BAMQueueItem *item in array){
        [self.moc deleteObject: item];
    }
}

- (void)restartQueue
{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:self.queueItemEntity];
    NSError *error = nil;
    NSArray *array = [self.moc executeFetchRequest:request error:&error];
    for(BAMQueueItem *item in array){
        [self.moc deleteObject: item];
    }
}


- (void)queueFilenames:(NSArray *)filenames
{    
    NSLog(@"BAMQueueController: queueFilenames: %@", [NSThread currentThread]);
    for (NSString *filename in filenames) {
        if([BAMOptimizeOperation filenameHasAtoms:filename]){
            NSURL *fileURL = [NSURL fileURLWithPath:filename];
            BAMOptimizeOperation *oo = [BAMOptimizeOperation createOptimizeOperationFromURL:fileURL];
            NSLog(@"creating object for: %@", filename);
            BAMQueueItem *queueItem = [BAMQueueItem queueItemForFilename:filename inManagedObjectContext:self.moc];
            oo.oid = [queueItem objectID];
            [self.operationQueue addObject: oo];
            [self startNextThread];
        }
    }
}

-(void)operationNotification:(NSNotification *)notification 
{
    NSLog(@"notified: %@", notification);
    
    NSManagedObjectID *oid = [[notification userInfo] objectForKey:@"oid"];
    NSString *status = [[notification userInfo] objectForKey:@"status"];
    BAMOptimizeOperation *sender = [notification object];
    if([sender respondsToSelector:@selector(isCancelled)] && sender.isCancelled){
    }else{
        if(status && oid){
            id objectFromOID = [self.moc objectWithID: oid];
            NSLog(@"[[objectFromOID entity] name]: %@", [[objectFromOID entity] name]);
            if([[[objectFromOID entity] name] isEqualToString:@"BAMQueueItem"]){
                BAMQueueItem *queueItem = objectFromOID;
                queueItem.statusMessage = status;
            }
        }
        [self startNextThread];
    }
}

//
// startNextThread
//
// Starts the next thread _if_ the current (idx = 0) thread is complete
//
-(void)startNextThread
{
    if([self.operationQueue count] > 0){
        BAMOptimizeOperation *oo = [self.operationQueue objectAtIndex: 0];
        if([oo isFinished]){
            [self.operationQueue removeObject: oo];
            if([self.operationQueue count] > 0){
                oo = [self.operationQueue objectAtIndex: 0];
                [oo start];
            }
        }else{
            if(![oo isExecuting]){
                [oo start];
            }
        }
    }
}

- (IBAction)openDocument:(id)sender;
{
    NSLog(@"doOpen"); 
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setAllowedFileTypes:[NSArray arrayWithObjects:@"mp4", @"m4v", nil]];
    
    [openPanel setAllowsMultipleSelection: YES];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setCanCreateDirectories:NO];
    [openPanel setCanChooseFiles:YES];
    
    [openPanel beginSheetModalForWindow:mainWindow completionHandler:^(NSInteger result) {
        
        if (result == NSFileHandlingPanelOKButton) {
            
            NSString *filename = [[openPanel URL] path];
            [self queueFilenames: [NSArray arrayWithObject: filename]];
        }
    }];
}


- (void)delete:(NSEvent *)event
{
    NSArray *selectedObjects = [self.arrayController selectedObjects];
    for(BAMQueueItem *queueItem in selectedObjects){
        NSLog(@"deleting queueItem: %@", queueItem);
        NSUInteger idx = [self.operationQueue indexOfObjectPassingTest:^(BAMOptimizeOperation *obj, NSUInteger idx, BOOL *stop){
            return [[obj.oid URIRepresentation] isEqual: [[queueItem objectID] URIRepresentation]];
        }];
        NSLog(@"idx: %lu", idx);
        if(idx != NSNotFound){
            BAMOptimizeOperation *oo = [self.operationQueue objectAtIndex:idx];
            NSLog(@"deleting from queue: %@", oo);
            NSLog(@"canceling: %@", oo);
            [oo cancel];
        }
        [self.moc deleteObject: queueItem];
    }
    [self.arrayController removeObjects:[self.arrayController selectedObjects]];
}

- (void)cancelAllOperations
{
    for(BAMOptimizeOperation *oo in self.operationQueue){
        id objectFromOID = [self.moc objectWithID: oo.oid];
        if ([objectFromOID isKindOfClass:[BAMQueueItem class]]) {
            BAMQueueItem *queueItem = objectFromOID;
            queueItem.statusMessage = @"Canceled";
        }
    }
    for(BAMOptimizeOperation *oo in self.operationQueue){
        [oo cancel];
    }
}

@end
