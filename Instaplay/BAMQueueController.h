//
//  SWQueueController.h
//  Instaplay
//
//  Created by Scott Wilson on 6/25/12.
//  Copyright (c) 2012 Scott Wilson. All rights reserved.
//

#import <Foundation/Foundation.h>
@class BAMOutputPath;

@interface BAMQueueController : NSObject <NSWindowDelegate>
{
    IBOutlet NSWindow *mainWindow;
    IBOutlet NSArrayController *arrayController;
    IBOutlet NSTableView *tableView;
    IBOutlet BAMOutputPath *outputPathView;
}
@property (strong, nonatomic) NSArrayController * arrayController;
@property (strong, nonatomic) NSTableView * tableView;

- (void)queueFilenames:(NSArray *)filenames;
- (void)startNextThread;
- (void)cancelAllOperations;

@end
