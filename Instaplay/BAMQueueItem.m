//
//  BAMQueueItem.m
//  Instaplay
//
//  Created by Scott Wilson on 7/4/12.
//  Copyright (c) 2012 Scott Wilson. All rights reserved.
//

#import "BAMQueueItem.h"


@implementation BAMQueueItem

@dynamic filename;
@dynamic statusCode;
@dynamic percentDone;
@dynamic statusMessage;
@dynamic dateAdded;
@dynamic dateComplete;


+ (BAMQueueItem *)queueItemForFilename:(NSString *)filename inManagedObjectContext:(NSManagedObjectContext *)moc
{
    BAMQueueItem *newItem = [NSEntityDescription insertNewObjectForEntityForName:@"BAMQueueItem" inManagedObjectContext:moc];
    newItem.filename = filename;
    newItem.dateAdded = [NSDate date];
    newItem.statusCode = 0;
    newItem.statusMessage = @"Added";
    return newItem;
}

- (NSString *)displayName
{
    return [self.filename lastPathComponent];
}

@end
