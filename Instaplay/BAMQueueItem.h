//
//  BAMQueueItem.h
//  Instaplay
//
//  Created by Scott Wilson on 7/4/12.
//  Copyright (c) 2012 Scott Wilson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface BAMQueueItem : NSManagedObject

@property (nonatomic, retain) NSString * filename;
@property (nonatomic, readonly) NSString * displayName;
@property (nonatomic, retain) NSNumber * statusCode;
@property (nonatomic, retain) NSNumber * percentDone;
@property (nonatomic, retain) NSString * statusMessage;
@property (nonatomic, retain) NSDate * dateAdded;
@property (nonatomic, retain) NSDate * dateComplete;

+ (BAMQueueItem *)queueItemForFilename:(NSString *)filename inManagedObjectContext:(NSManagedObjectContext *)moc;

- (NSString *)displayName;

@end
