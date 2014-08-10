//
//  SWOptimizeOperation.h
//  Instaplay
//
//  Created by Scott Wilson on 6/23/12.
//  Copyright (c) 2012 Scott Wilson. All rights reserved.
//

#define SWOperationNotification   @"SWOperationNotification"

#import <Foundation/Foundation.h>

@interface BAMOptimizeOperation : NSThread

@property (strong, nonatomic) NSManagedObjectID * oid;

+(BAMOptimizeOperation *)createOptimizeOperationFromURL:(NSURL *)fileURL;
+(BOOL)filenameHasAtoms:(NSString *)filename;

-(void)main;
-(void)readTopLevelAtoms;
-(BOOL)writeOptimizedFileToURL;

@end
