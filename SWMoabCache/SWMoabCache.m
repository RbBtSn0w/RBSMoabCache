//
//  SWMoabCache.m
//
// Copyright (c) <2014-2017> Rbbtsn0w
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "SWMoabCache.h"
#import <sys/xattr.h>
#import <sys/stat.h>


#if OS_OBJECT_USE_OBJC
    #undef SW_PROPERTY_STRONG
    #undef SW_PROPERTY_GCD_STRONG
    #define SW_PROPERTY_STRONG strong
    #define SW_PROPERTY_GCD_STRONG strong
#else
    #undef SW_PROPERTY_STRONG
    #undef SW_PROPERTY_GCD_STRONG
    #define SW_PROPERTY_STRONG retain
    #define SW_PROPERTY_GCD_STRONG assign
#endif


NS_ASSUME_NONNULL_BEGIN

static NSString *const kSWMoabCacheErrorDomain = @"com.Rbbtsn0w.SWMoabCache.cache";

static NSString *const kCacheQueueName = @"com.Rbbtsn0w.SWMoabCache.cache";

static NSString *const kAllNameKeys = @"kSWMoabCacheNameKeys";



static inline NSString *URLEncodeString(NSString *string);

static inline long long fileSizeAtPath(NSString *filePath);

NSString* AllNameKeysBySearchPathDirectory(NSSearchPathDirectory directory);

@interface SWMoabCache ()

@property (nonatomic, SW_PROPERTY_STRONG)       NSCache *cache;
@property (nonatomic, SW_PROPERTY_STRONG)       NSFileManager *fileManager;
@property (nonatomic, SW_PROPERTY_GCD_STRONG)   dispatch_queue_t queue;
@property (nonatomic, copy)                     NSString *cachesPath;

@end

@implementation SWMoabCache


#pragma mark    -   Accessors
- (void)setMaxMemoryCost:(NSUInteger)maxMemoryCost {
    dispatch_barrier_sync(self.queue, ^{
        self.cache.totalCostLimit = maxMemoryCost;
    });
}

- (NSUInteger)maxMemoryCost {
    return self.cache.totalCostLimit;
}

- (NSUInteger)maxMemoryCountLimit {
    return self.cache.countLimit;
}

- (void)setMaxMemoryCountLimit:(NSUInteger)maxCountLimit {
    dispatch_barrier_sync(self.queue, ^{
        self.cache.countLimit = maxCountLimit;
    });
}

#pragma mark		Object lifecycle
- (void)dealloc
{
    dispatch_barrier_sync(self.queue, ^{}); //wait till the queue will finish all tasks
#if !__has_feature(objc_arc)
    [_cache release];
    [_fileManager release];
    [_cachesPath release];
    
    dispatch_release(_queue);
    [super dealloc];
#endif
}


#pragma mark    -   Private
- (NSString *)desiredPathForObjectForKey:(NSString *)key
{
    return [self.cachesPath stringByAppendingPathComponent:URLEncodeString(key)];
}

- (void)saveAndCheckRepeatName:(NSString*)name withSearchPathDirectory:(NSSearchPathDirectory) directory
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *allNameKeys = AllNameKeysBySearchPathDirectory(directory);
    NSArray *finaArray = [userDefaults arrayForKey:allNameKeys];
    NSMutableArray *mValues = nil;
    
    if (finaArray){
        mValues = [finaArray mutableCopy];
    }else{
        mValues = [[NSMutableArray alloc] init];
    }
    
    NSInteger indx = [mValues indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        return [obj isEqualToString:name];
    }];
    if (indx == NSNotFound) {
        [mValues addObject:name];
        [userDefaults setObject:mValues forKey:allNameKeys];
    }
    
#if !__has_feature(objc_arc)
    [mValues release];
#endif
    
}

- (void)removeAllObjectsBySync
{
    dispatch_barrier_sync(self.queue, ^{
        [self.cache removeAllObjects];
        NSArray *files = [self.fileManager contentsOfDirectoryAtPath:self.cachesPath error:NULL];
        for (NSString *file in files) {
            [self.fileManager removeItemAtPath:[self.cachesPath stringByAppendingPathComponent:file] error:NULL];
        }
    });
}



#pragma mark    -   Interface

- (nullable instancetype)initWithName:(NSString *)name error:(NSError *__autoreleasing *)e searchPathDirectory:(NSSearchPathDirectory) directory {
    self = [super init];
    
    __autoreleasing NSError *error = nil;
    if (self) {
        NSString *queueName = [NSString stringWithFormat:@"%@_%@-%@",kCacheQueueName, name, [[NSUUID UUID] UUIDString]];
        self.queue = dispatch_queue_create([queueName UTF8String], DISPATCH_QUEUE_CONCURRENT);
        self.fileManager = [[NSFileManager alloc] init];
        self.cache = [[NSCache alloc] init];
        
        [self.cache setName:name];
        
        NSString *userCaches = [NSSearchPathForDirectoriesInDomains(directory, NSUserDomainMask, YES) lastObject];
        self.cachesPath = [userCaches stringByAppendingPathComponent:URLEncodeString(name)];
#if !__has_feature(objc_arc)
        [_cachesPath retain];
#endif
        BOOL isDirectory = NO;
        if (![self.fileManager fileExistsAtPath:self.cachesPath isDirectory:&isDirectory]) {
            [self.fileManager createDirectoryAtPath:self.cachesPath withIntermediateDirectories:YES attributes:nil error:&error];
        }
        else if (!isDirectory) {
            error = [NSError errorWithDomain:kSWMoabCacheErrorDomain code:SWMoabCacheErrorDirectoryIsFile userInfo:@{}];
        }
        
        if (error) {
            if (e) {
                *e = error;
            }
#if !__has_feature(objc_arc)
            [self release];
#endif
            self = nil;
        }else{
            
            [self saveAndCheckRepeatName:name withSearchPathDirectory:directory];
        }
    }
    
    return self;
}

- (nullable instancetype)initWithName:(NSString *)name error:(NSError *__autoreleasing *)error
{
    return [self initWithName:name error:error searchPathDirectory:NSCachesDirectory];
}

- (NSString *)name
{
    return [_cache name];
}

- (void)setObject:(id<NSCoding>)object forKey:(NSString *)key
{
    if (key != nil) {
        if (!object && [self objectExistsForKey:key]) {
            [self removeObjectForKey:key];
        }
        else {
            if ([(id)object conformsToProtocol:@protocol(NSCoding)]) {
                dispatch_barrier_async(_queue, ^{
                    @try {
                        [_cache setObject:object forKey:key];
                        [NSKeyedArchiver archiveRootObject:object toFile:[self desiredPathForObjectForKey:key]];
                    }
                    @catch (NSException *exception) {
                        NSLog(@"Exception %@",exception);
                        [self removeAllObjects];
                    }
                    @catch (...){
                        NSLog(@"Exception catch ...");
                        [self removeAllObjects];
                    }
                });
            }
        }
    }
}

- (BOOL)objectExistsForKey:(NSString *)key
{
    __block BOOL objectExists = NO;
    if (key != nil) {
        dispatch_sync(_queue, ^{
            objectExists = [_cache objectForKey:key] != nil;
            if (!objectExists) {
                objectExists = [_fileManager fileExistsAtPath:[self desiredPathForObjectForKey:key]];
            }
        });
    }
    return objectExists;
}

- (nullable id)objectForKey:(NSString *)key
{
    __block id object = nil;
    if (key != nil) {
        dispatch_sync(_queue, ^{
            object = [_cache objectForKey:key];
#if !__has_feature(objc_arc)
            [object retain];
#endif
            if (!object) {
                @try {
                    object = [NSKeyedUnarchiver unarchiveObjectWithFile:[self desiredPathForObjectForKey:key]];
                }
                @catch (NSException *exception) {
                    NSLog(@"Exception %@",exception);
                    object = nil;
                    [self removeAllObjects];
                }
                @catch (...){
                    NSLog(@"Exception catch ...");
                    object = nil;
                    [self removeAllObjects];
                }
                
                if (object != nil) {
#if !__has_feature(objc_arc)
                    [object retain]; //this one is for autorelease before return
                    [object retain]; //this one is for autorelease in barrier's block
#endif
                    dispatch_barrier_async(_queue, ^{
                        [_cache setObject:object forKey:key];
#if !__has_feature(objc_arc)
                        [object release];
#endif
                    });
                }
            }
        });
    }
#if !__has_feature(objc_arc)
    [object autorelease];
#endif
    return object;
}

- (void)removeObjectForKey:(NSString *)key
{
    if (key != nil) {
        dispatch_barrier_async(_queue, ^{
            [_cache removeObjectForKey:key];
            [_fileManager removeItemAtPath:[self desiredPathForObjectForKey:key] error:NULL];
        });
    }
}

- (void)removeAllObjects
{
    dispatch_barrier_async(_queue, ^{
        [_cache removeAllObjects];
        NSArray *files = [_fileManager contentsOfDirectoryAtPath:_cachesPath error:NULL];
        for (NSString *file in files) {
            [_fileManager removeItemAtPath:[_cachesPath stringByAppendingPathComponent:file] error:NULL];
        }
    });
}

- (void)clearMemory
{
    dispatch_barrier_async(_queue, ^{
        [_cache removeAllObjects];
    });
}

- (void)setObject:(id)obj forKeyedSubscript:(NSString *)key
{
    [self setObject:obj forKey:key];
}

- (nullable id)objectForKeyedSubscript:(NSString *)key
{
    return [self objectForKey:key];
}

- (nullable NSString *)pathForObjectForKey:(NSString *)key
{
    return [self objectExistsForKey:key] ? [self desiredPathForObjectForKey:key] : nil;
}

+ (void) removeAllNameCache
{
    @try {
        
        NSUserDefaults *userdefault = [NSUserDefaults standardUserDefaults];
        
        NSArray *allChannels = [userdefault arrayForKey:kAllNameKeys];
        
        if (allChannels && [allChannels count] > 0){
            
            for (NSString *channelID in allChannels) {
                if ([channelID isEqualToString:@"get_detail_info"]) {
                    continue;
                }
                NSError *error = nil;
                SWMoabCache *moabCache = [[SWMoabCache alloc] initWithName:channelID error:&error];
                [moabCache removeAllObjectsBySync];
                if (error) {
                    NSLog(@"%@",[NSString stringWithFormat:@"Remove channel %@ cache was failure",channelID]);
                }
#if !__has_feature(objc_arc)
                [SWMoabCache release];
#endif
            }
        }
        
        [userdefault removeObjectForKey:kAllNameKeys];
        [userdefault synchronize];
    }
    @catch (NSException *exception) {
        NSLog(@"Remove all channel's cache was failure!, Exception:%@",exception);
    }
}

+ (void)removeAllNameCacheBySearchPathDirectory:(NSSearchPathDirectory) directory{
    @try {
        
        NSUserDefaults *userdefault = [NSUserDefaults standardUserDefaults];
        
        NSString *allNameKeys = AllNameKeysBySearchPathDirectory(directory);
        NSArray *allChannels = [userdefault arrayForKey:allNameKeys];
        
        if (allChannels && [allChannels count] > 0){
            
            for (NSString *channelID in allChannels) {
                if ([channelID isEqualToString:@"get_detail_info"]) {
                    continue;
                }
                NSError *error = nil;
                SWMoabCache *moabCache = [[SWMoabCache alloc] initWithName:channelID error:&error searchPathDirectory:directory];
                [moabCache removeAllObjectsBySync];
                if (error) {
                    NSLog(@"%@",[NSString stringWithFormat:@"Remove channel %@ cache was failure",channelID]);
                }
#if !__has_feature(objc_arc)
                [SWMoabCache release];
#endif
            }
        }
        
        [userdefault removeObjectForKey:allNameKeys];
        [userdefault synchronize];
    }
    @catch (NSException *exception) {
        NSLog(@"Remove all channel's cache was failure!, Exception:%@",exception);
    }
}

+ (long long) statisticsCacheFolderSize
{
    @try {
        long long filesz = 0;
        
        NSUserDefaults *userdefault = [NSUserDefaults standardUserDefaults];
        
        NSArray *allChannels = [userdefault arrayForKey:kAllNameKeys];
        
        if (allChannels && [allChannels count] > 0){
            
            for (NSString *channelID in allChannels) {
                NSError *error = nil;
                SWMoabCache *moabCache = [[SWMoabCache alloc] initWithName:channelID error:&error];
                
                NSString *cachePath = moabCache->_cachesPath;
                
                filesz += fileSizeAtPath(cachePath);
                
                if (error) {
                    NSLog(@"%@",[NSString stringWithFormat:@"Remove channel %@ cache was failure",channelID]);
                }
#if !__has_feature(objc_arc)
                [SWMoabCache release];
#endif
            }
        }
        
        return filesz;
    }
    @catch (NSException *exception) {
        NSLog(@"Remove all channel's cache was failure!, Exception:%@",exception);
    }
}


#pragma mark    -   Delegate


@end

NS_ASSUME_NONNULL_END
static inline NSString *URLEncodeString(NSString *string)
{
#if __has_feature(objc_arc)
    return (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                                 (__bridge CFStringRef)string,
                                                                                 NULL,
                                                                                 (__bridge CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ",
                                                                                 kCFStringEncodingUTF8
                                                                                 );
#else
    return [(NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                (CFStringRef)string,
                                                                NULL,
                                                                (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ",
                                                                kCFStringEncodingUTF8
                                                                ) autorelease];
#endif
}


static inline long long fileSizeAtPath(NSString *filePath)
{
    struct stat st;
    if (lstat([filePath cStringUsingEncoding:NSUTF8StringEncoding], &st) == 0) {
        return st.st_size;
    }
    return 0;
}

NSString* AllNameKeysBySearchPathDirectory(NSSearchPathDirectory directory){
    
    NSString *name = nil;
    if (directory == NSCachesDirectory) {
        name = kAllNameKeys;
    }else{
        name = [NSString stringWithFormat:@"%@_%tu", kAllNameKeys, directory];
    }
    
    return name;
}
