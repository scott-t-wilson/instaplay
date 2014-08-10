//
//  SWOptimizeOperation.m
//  Instaplay
//
//  Created by Scott Wilson on 6/23/12.
//  Copyright (c) 2012 Scott Wilson. All rights reserved.
//

#import "BAMOptimizeOperation.h"
#import "BAMAppDelegate.h"
#import "NSNotificationCenter+MainThread.h"
#include <sys/stat.h>

UInt64 hton64(UInt64 hostInt){
    UInt64 hWord = htonl(hostInt & 0xFFFFFFFF);
    UInt64 lWord = htonl((hostInt >> 32) & 0xFFFFFFFF);
    return hWord << 32 | lWord;
}

UInt64 ntoh64(UInt64 networkInt){
    UInt64 hWord = ntohl(networkInt & 0xFFFFFFFF);
    UInt64 lWord = ntohl((networkInt >> 32) & 0xFFFFFFFF);
    return hWord << 32 | lWord;
}

@interface BAMAtom : NSObject
@property (strong, nonatomic) NSData * data;
@property (strong, nonatomic) NSString * type;
@property (strong, nonatomic) NSMutableArray * childAtoms;
@property (nonatomic) UInt64 size;
@property (nonatomic) off_t offset;
@property (nonatomic) NSData * offsetData;
+(BAMAtom *)atomForData:(unsigned char *)data atPosition:(off_t)position;
+(BAMAtom *)atomAtPosition:(size_t)position fromFile:(int)fd;
- (void)writeAtomToFD:(int)writeFD fromFD:(int)readFD;
- (BOOL)isMoovType;
- (BOOL)isOffsetParentType;
- (BOOL)isOffsetType;
@end

@implementation BAMAtom
@synthesize data = data_;
@synthesize type = type_;
@synthesize size = size_;
@synthesize offset = offset_;
@synthesize childAtoms = childAtoms_;
@synthesize offsetData = offsetData_;
+(BAMAtom *)atomForData:(unsigned char *)data atPosition:(off_t)position
{
    BAMAtom *newAtom = [[BAMAtom alloc] init];
    newAtom.data = [NSData dataWithBytes: data length:8];
    newAtom.type = [NSString stringWithFormat:@"%c%c%c%c", data[4], data[5], data[6], data[7]];
    newAtom.size = ntohl( ((UInt32 *) data)[0] );
//    newAtom.size = (UInt32)data[0] << 24 | (UInt32)data[1] << 16 | (UInt32)data[2] << 8 | (UInt32)data[3];
    newAtom.offset = position;
    newAtom.childAtoms = NULL;
    newAtom.offsetData = NULL;
    return newAtom;
}

+(BAMAtom *)atomAtPosition:(size_t)position fromFile:(int)fd
{
    BAMAtom *newAtom = [[BAMAtom alloc] init];
    
    size_t atomDataLength = 16;
    unsigned char atomInfo[atomDataLength];
    lseek(fd, position, SEEK_SET);
    read(fd, &atomInfo, atomDataLength);
    
    newAtom.type = [NSString stringWithFormat:@"%c%c%c%c", atomInfo[4], atomInfo[5], atomInfo[6], atomInfo[7]];
    newAtom.size = ntohl(((UInt32 *) atomInfo)[0]);
    
    if(newAtom.size == 1){
//        UInt64 hWord = ntohl(((UInt32 *) atomInfo)[2]);
//        UInt64 lWord = ntohl(((UInt32 *) atomInfo)[3]);
//        UInt64 realSize = hWord << 32 | lWord;
        newAtom.size = ntoh64(((UInt64 *) atomInfo)[1]);
        
//        NSLog(@"64bit... hWord: %llu, lWord: %llu, final: %llu", hWord, lWord, realSize);
//        NSLog(@"ntoh64: final: %llu", ntoh64(((UInt64 *) atomInfo)[1]));
//        NSLog(@"real: %llx, raw: %llx, ntoh64: %llx", realSize, ((UInt64 *) atomInfo)[1], ntoh64(((UInt64 *) atomInfo)[1]));
    }else{
        //Its a regular 32bit atom, reset position
        atomDataLength = 8;
    }
    lseek(fd, position + 8, SEEK_SET);
    
    newAtom.data = [NSData dataWithBytes: atomInfo length:atomDataLength];
    newAtom.offset = position;
    newAtom.childAtoms = NULL;
    newAtom.offsetData = NULL;
    return newAtom;
}


- (BOOL)isMoovType
{
    return [@"moov" isEqualToString:self.type];
}

- (BOOL)isOffsetParentType
{
    return [@"trak" isEqualToString:self.type] ||
    [@"mdia" isEqualToString:self.type] ||
    [@"minf" isEqualToString:self.type] ||
    [@"stbl" isEqualToString:self.type];
}

- (BOOL)isOffsetType
{
    return [@"stco" isEqualToString:self.type] ||
    [@"co64" isEqualToString:self.type];
}

- (BOOL)is32Bit
{
    return [@"stco" isEqualToString:self.type];
}

- (BOOL)is64Bit
{
    return [@"co64" isEqualToString:self.type];
}


- (void)writeAtomToFD:(int)writeFD fromFD:(int)readFD
{
    
    // 1024 buf -> 44s
    // 32k -> 38s
    // 64k -> 35s
    //128k -> 42s
    // 1M -> 46s
    size_t bufSize = 1024 * 64;
    void *buf = valloc(bufSize);
//    NSLog(@"using buf size: %zu", bufSize);
//    NSLog(@"starting atom write: %llu", self.size);
    NSThread *myThread = [NSThread currentThread];
    if([myThread isMainThread]){
        myThread = NULL;
    }

    size_t bytesLeft = self.size;
    size_t bytesRead = bytesLeft;
    lseek(readFD, self.offset, SEEK_SET);
    //    write(writeFD, [self.data bytes], 8);
    while((bytesLeft > 0) && (bytesRead != 0)){
        //        NSLog(@"sizeof(buf): %lu", bufSize);
        //        NSLog(@"bytesLeft: %zu", bytesLeft);
        bytesRead = bufSize < bytesLeft ? bufSize : bytesLeft;
        //        NSLog(@"bytesRead: %zu", bytesRead);
        bytesRead = read(readFD, buf, bytesRead);
        ssize_t bytesWritten = write(writeFD, buf, bytesRead);
        if (bytesWritten == -1){
            NSLog(@"error: %s", strerror(errno));
        }
        if(bytesRead != bytesWritten){
            NSLog(@"fail");
        }
        bytesLeft -= bytesRead;
        if(myThread && [myThread isCancelled]){
            NSLog(@"canceled");
            break;
        }
    }
    free(buf);
//    NSLog(@"finished atom write:");
}

- (NSString*)description
{   //Atom ftyp @ 0 of size: 32, ends @ 32
    return [NSString stringWithFormat:@"Atom %@ @ %lld of size: %lld", self.type, self.offset, self.size];
}
@end

NSMutableArray * readAtomsAtLocation(int fd, off_t startLocation, off_t maxRead, BAMAtom *moovAtom)
{
    NSLog(@"readAtomsAtLocation(%d, %lld, %lld)", fd, startLocation, maxRead);
    NSMutableArray *atoms = [NSMutableArray arrayWithCapacity: 16];
    off_t location = lseek(fd, startLocation, SEEK_SET);
    
    while (lseek(fd, 0, SEEK_CUR) < (startLocation + maxRead)){
        //    while (bytesRead == 8) {
        BAMAtom *atom = [BAMAtom atomAtPosition:location fromFile:fd];

//        NSLog(@"atom: %@", atom);
        [atoms addObject: atom];
        if([atom isMoovType]){
//            NSLog(@"moov atom: %@", atom);
            atom.childAtoms = [NSMutableArray arrayWithCapacity:10];
            readAtomsAtLocation(fd, location + 8, atom.size - 8, atom);
//            NSLog(@"moovOffsets: %@", atom.childAtoms);
        }
        
        if([atom isOffsetType]){
//            NSLog(@"offset atom: %@", atom);
            void *buf = malloc(atom.size - 8);
            read(fd, buf, atom.size - 8);
            atom.offsetData = [NSData dataWithBytes:buf length:atom.size - 8];
            free(buf);
            [moovAtom.childAtoms addObject: atom];
            return NULL;
        }else{
            if([atom isOffsetParentType]){
//                NSLog(@"parent atom: %@", atom);
                readAtomsAtLocation(fd, location + 8, atom.size - 8, moovAtom);
            }
        }
        location = lseek(fd, atom.offset + atom.size, SEEK_SET);        
    }
    return atoms;
}

@interface BAMOptimizeOperation()
@property (strong, nonatomic) NSFileHandle * fileHandle;
@property (strong, nonatomic) NSMutableArray * atoms;
@property (strong, nonatomic) BAMAtom *moovAtom;
@property (strong, nonatomic) NSURL *inputURL;
@property (strong, nonatomic) NSURL *outputURL;
@property (strong, nonatomic) NSURL *tempURL;
@property (strong, nonatomic) NSURL *originalURL;
@property (strong, atomic) NSString *status;
@end

BOOL fileURLsAreEqual(NSURL *url1, NSURL *url2){
    if ([url1 isEqual:url2]) {
		return YES;
	} else {
		NSError *error = nil;
		id resourceIdentifier1 = nil;
		id resourceIdentifier2 = nil;
        
		if (![url1 getResourceValue:&resourceIdentifier1 forKey:NSURLFileResourceIdentifierKey error:&error]) {
            return NO;
		}
        
		if (![url2 getResourceValue:&resourceIdentifier2 forKey:NSURLFileResourceIdentifierKey error:&error]) {
            return NO;
		}
        
		return [resourceIdentifier1 isEqual:resourceIdentifier2];
	}
    return NO;
}

@implementation BAMOptimizeOperation

@synthesize inputURL = inputURL_;
@synthesize outputURL = outputURL_;
@synthesize tempURL = tempURL_;
@synthesize originalURL = originalURL_;
@synthesize fileHandle = fileHandle_;
@synthesize atoms = atoms_;
@synthesize moovAtom = moovAtom_;
@synthesize status = status_;
@synthesize oid;

//+(SWOptimizeOperation *)optimizeOperationFromURL:(NSURL *)fileURL
//{
//    SWOptimizeOperation *newOperation = [[SWOptimizeOperation alloc] init];
//    newOperation.fileHandle = [NSFileHandle fileHandleForReadingFromURL:fileURL error:NULL];
//    newOperation.atoms = [NSMutableArray arrayWithCapacity:10];
//    return newOperation;
//}

+(BAMOptimizeOperation *)createOptimizeOperationFromURL:(NSURL *)fileURL
{
    NSString *filename = [fileURL lastPathComponent];
    NSString *originalPath = [fileURL.path stringByAppendingPathExtension: @"orig"];
    BAMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];    
//    NSString *outputPath = [appDelegate.outputURL path];
    
    BAMOptimizeOperation *newOperation = [[BAMOptimizeOperation alloc] init];
    
    
    
    newOperation.inputURL = fileURL;
    newOperation.outputURL = [NSURL fileURLWithPath:[[appDelegate.outputURL path] stringByAppendingPathComponent: filename]];
    newOperation.tempURL = [NSURL fileURLWithPath:[[[appDelegate.outputURL path] stringByAppendingPathComponent: filename] stringByAppendingPathExtension: @"tmp"]];
    newOperation.originalURL = fileURL;

    
    BOOL URLsAreEqual = fileURLsAreEqual(newOperation.inputURL, newOperation.outputURL);
    NSLog(@"URLsAreEqual: %d", URLsAreEqual);
    if(URLsAreEqual){
        newOperation.originalURL = [NSURL fileURLWithPath: originalPath];
    }

    //    newOperation.tempURL = newOperation.tempURL;

//    if([[NSFileManager defaultManager] createFileAtPath: tmpPath contents: NULL attributes: NULL]){
//        newOperation.inputURL = fileURL;
//        newOperation.tempURL = [NSURL fileURLWithPath: tmpPath];
//        
//        newOperation.originalURL = [NSURL fileURLWithPath: originalPath];
//        newOperation.outputURL = fileURL;
//    }else{
//        newOperation.inputURL = fileURL;
//        tmpPath = [outputPath stringByAppendingPathComponent: filename];
//        NSLog(@"tmpPath: %@", tmpPath);
//        newOperation.tempURL = [NSURL fileURLWithPath:[outputPath stringByAppendingPathComponent: filename]];
//        
//        newOperation.originalURL = fileURL;
//        newOperation.outputURL = newOperation.tempURL;
//    }
    
    NSLog(@"inputURL: %@", newOperation.inputURL);
    NSLog(@"tempURL: %@", newOperation.tempURL);
    NSLog(@"originalURL: %@", newOperation.originalURL);
    NSLog(@"outputURL: %@", newOperation.outputURL);
    newOperation.fileHandle = NULL;
    newOperation.atoms = [NSMutableArray arrayWithCapacity:16];
    newOperation.moovAtom = NULL;
    newOperation.status = @"Added";
    return newOperation;
}

+(BOOL)filenameHasAtoms:(NSString *)filename
{
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:filename];
    int fd = [fileHandle fileDescriptor];
    
    UInt32 atomSize;
    unsigned char atomInfo[8];
    ssize_t bytesRead;
    
    bytesRead = pread(fd, &atomInfo, 8, 0);
    atomSize = (UInt32)atomInfo[0] << 24 | (UInt32)atomInfo[1] << 16 | (UInt32)atomInfo[2] << 8 | (UInt32)atomInfo[3];
    return (bytesRead == 8) && (strncmp("ftyp", (const char *) atomInfo + 4, 4) == 0);
}

-(BOOL)fileHasAtoms
{
    int fd = [self.fileHandle fileDescriptor];
    
    UInt32 atomSize;
    unsigned char atomInfo[8];
    ssize_t bytesRead;
    
    bytesRead = pread(fd, &atomInfo, 8, 0);
    atomSize = (UInt32)atomInfo[0] << 24 | (UInt32)atomInfo[1] << 16 | (UInt32)atomInfo[2] << 8 | (UInt32)atomInfo[3];
    return (bytesRead == 8) && (strncmp("ftyp", (const char *) atomInfo + 4, 4) == 0);
}

-(void)readTopLevelAtoms
{
    int fd = [self.fileHandle fileDescriptor];
    //    
    //    unsigned char atomInfo[8];
    //    ssize_t bytesRead = 8;
    //    int location = lseek(fd, 0, SEEK_SET);
    struct stat fileStat;
    fstat(fd, &fileStat);
    self.atoms = readAtomsAtLocation(fd, 0, fileStat.st_size, NULL);
    //    while (bytesRead == 8) {
    //        bytesRead = read(fd, &atomInfo, 8);
    //        SWAtom *atom = [SWAtom atomForData:atomInfo atPosition:location];
    //        location = lseek(fd, atom.size - 8, SEEK_CUR);
    //        [self.atoms addObject: atom];
    //    }
    NSLog(@"atoms: %@", self.atoms);
}

-(BOOL)isConcurrent
{
    return YES;
}

-(BOOL)writeOptimizedFileToURL
{
    if([self fileHasAtoms] && [self.atoms count] >= 2){
        NSUInteger idx = [self.atoms indexOfObjectPassingTest:^(BAMAtom *obj, NSUInteger idx, BOOL *stop){
            return [@"moov" isEqualToString:obj.type];
        }];
        switch (idx) {
            case NSNotFound:
//                NSLog(@"No moov atom");
                self.status = @"Skipped";
                return NO;
                break;
            case 1:
//                NSLog(@"File already optimized");
                self.status = @"Already Optimized";
                return NO;
                break;
            default:
                self.moovAtom = [self.atoms objectAtIndex:idx];
//                NSLog(@"Starting optimization");
                [[NSFileManager defaultManager] createFileAtPath: [self.tempURL path] contents: NULL attributes: NULL];
                NSFileHandle *outHandle = [NSFileHandle fileHandleForUpdatingAtPath:[self.tempURL path]];
                int inFD = [self.fileHandle fileDescriptor];
                int outFD = [outHandle fileDescriptor];
                if (outFD == -1){
//                    NSLog(@"error: %s", strerror(errno));
                }
                
                //Move the moov atom to the 2nd position
                [self.atoms removeObjectAtIndex: idx];
                [self.atoms insertObject:self.moovAtom atIndex:1];
                
                //Write all the atoms back out in their new order
                for (BAMAtom *atom in self.atoms) {
//                    NSLog(@"writing out %@ atom, size %llul", atom.type, atom.size);
                    [atom writeAtomToFD:outFD fromFD:inFD];
                    if(self.isCancelled){
                        self.status = @"Canceled";
                        return NO;
                    }
                }
                
                //Read the new files top level atoms back in, so that we:
                // -have the location of the chunk offset atoms for updating
                // -and have the new location of the mdat atom to calculate new offsets
                struct stat fileStat;
                fstat(outFD, &fileStat);
//                NSLog(@"Reading new atoms");
//                off_t newLocation = lseek(outFD, 0, SEEK_SET);
//                NSLog(@"location: %lld", newLocation);
                NSMutableArray *newAtoms = readAtomsAtLocation(outFD, 0, fileStat.st_size, NULL);
//                NSLog(@"newAtoms: %@", newAtoms);
                idx = [newAtoms indexOfObjectPassingTest:^(BAMAtom *obj, NSUInteger idx, BOOL *stop){
                    return [@"moov" isEqualToString:obj.type];
                }];
                if(idx == NSNotFound){
//                    NSLog(@"No moov atom, wtf");
                    self.status = @"Error";
                    return NO;
                }
                BAMAtom *newMoovAtom = [newAtoms objectAtIndex:idx];
//                NSLog(@"New moov offsets: %@", newMoovAtom.childAtoms);

//                NSLog(@"updating offsets");
                
                //Get the location of the 'mdat' atom in both files, use the difference as the offset to add
                //when adjust the chunk offsets
                idx = [self.atoms indexOfObjectPassingTest:^(BAMAtom *obj, NSUInteger idx, BOOL *stop){
                    return [@"mdat" isEqualToString:obj.type];
                }];
                if(idx == NSNotFound){
//                    NSLog(@"No mdat atom in self");
                    self.status = @"Error";
                    return NO;
                }
                BAMAtom *originalMdatAtom = [self.atoms objectAtIndex:idx];
                idx = [newAtoms indexOfObjectPassingTest:^(BAMAtom *obj, NSUInteger idx, BOOL *stop){
                    return [@"mdat" isEqualToString:obj.type];
                }];
                if(idx == NSNotFound){
//                    NSLog(@"No new mdat atom");
                    self.status = @"Error";
                    return NO;
                }
                BAMAtom *newMdatAtom = [newAtoms objectAtIndex:idx];
                off_t offset = newMdatAtom.offset - originalMdatAtom.offset;
                
                for (BAMAtom *newOffsetAtom in newMoovAtom.childAtoms) {
                    UInt32 *offsets = malloc([newOffsetAtom.offsetData length]);
                    [newOffsetAtom.offsetData getBytes:offsets length:[newOffsetAtom.offsetData length]];
                    if ([newOffsetAtom is32Bit]) {
//                        NSLog(@"atom is 32bit");
                        UInt32 *offset32 = offsets + 2;
                        UInt32 numberOfOffsets = ntohl(offsets[1]);
                        for(UInt32 i = 0; i < numberOfOffsets; i++){
                            offset32[i] = htonl(  ntohl(offset32[i]) + offset );
                        }
                        lseek(outFD, newOffsetAtom.offset + 16, SEEK_SET);
                        write(outFD, offset32, numberOfOffsets * 4);
                    }
                    if ([newOffsetAtom is64Bit]) {
//                        NSLog(@"atom is 64bit");
                        UInt64 *offset64 = (UInt64 *)(offsets + 2);
                        [newOffsetAtom.offsetData getBytes:offsets length:[newOffsetAtom.offsetData length]];
                        UInt32 numberOfOffsets = ntohl(offsets[1]);
                        
                        for(UInt64 i = 0; i < numberOfOffsets; i++){
                            offset64[i] = hton64 (  ntoh64(offset64[i]) + offset );
                        }
                        lseek(outFD, newOffsetAtom.offset + 16, SEEK_SET);
                        write(outFD, offset64, numberOfOffsets * 8);
                    }
                    free(offsets);
                }
                
                
//                NSLog(@"done, closeing handle");
                [outHandle synchronizeFile];
                [outHandle closeFile];
                break;
        }
        self.status = @"Complete";
        return YES;
//        NSLog(@"moov idx: %lu", idx);
        //
        //        SWAtom *atom = [self.atoms objectAtIndex: 1];
        //        if(![@"moov" isEqualToString:atom.type]){
        //        }
    }
    return NO;
}

- (void)main{
    NSLog(@"SWOptimizeOperation: main: %@", [NSThread currentThread]);
    
    //starting notice
    NSNotificationCenter *dc = [NSNotificationCenter defaultCenter];
    
    self.status = @"Optimizing";
    [dc postNotificationOnMainThreadName:SWOperationNotification 
                                  object:self 
                                userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                          self.status, @"status",
                                          self.oid,      @"oid",
                                          nil]];
                              
    self.fileHandle = [NSFileHandle fileHandleForReadingFromURL:self.inputURL error:NULL];
    [self readTopLevelAtoms];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    if([self writeOptimizedFileToURL]){
        if(![self.inputURL isEqualTo: self.originalURL]){
            [fm moveItemAtURL:self.inputURL toURL:self.originalURL error:NULL];
        }
        if(![self.tempURL isEqualTo: self.outputURL]){
            [fm moveItemAtURL:self.tempURL toURL:self.outputURL error:NULL];
        }
        //complete notice
        [dc postNotificationOnMainThreadName:SWOperationNotification 
                                      object:self 
                                    userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                              self.status, @"status",
                                              self.oid,      @"oid",
                                              nil]];
    }else{
        //it failed, may need to clean up a half-written temp file
        //
        [dc postNotificationOnMainThreadName:SWOperationNotification 
                                      object:self 
                                    userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                              self.status, @"status",
                                              self.oid,      @"oid",
                                              nil]];
    }
    if(![self.tempURL isEqualTo: self.outputURL]){
        [fm removeItemAtURL:self.tempURL error:NULL];
    }

}

@end
