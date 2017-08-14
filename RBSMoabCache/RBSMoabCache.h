//
//  RBSMoabCache.h
//
// Copyright (c) <2014-2017> RbBtSn0w
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum {
    RBSMoabCacheErrorDirectoryIsFile = 1001
} RBSMoabCacheError;

extern NSString * RBSMoabCacheErrorDomain;

@interface RBSMoabCache : NSObject

/**
 The maximum "total cost" of the in-memory image cache. The cost function is the number of pixels held in memory.
 */
@property (assign, nonatomic) NSUInteger maxMemoryCost;

/**
 The maximum number of objects the cache should hold.
 */
@property (assign, nonatomic) NSUInteger maxMemoryCountLimit;


#pragma mark    -   Methods

/**
 Designated initializer. You can custom the file document path.

 @param name Used to name internal NSCache instance and to name a folder which is used to store cached values persistently.
 @param error Will be assigned if something went wrong during initializing.
 @param directory Will create document by NSSearchPathDirectory.
 @return An instance of RBSMoabCache
 */
- (nullable instancetype)initWithName:(NSString *)name error:(NSError *__autoreleasing *)error searchPathDirectory:(NSSearchPathDirectory) directory;

/**
 Designated initializer. Default document by NSCachesDirectory.

 @param name Used to name internal NSCache instance and to name a folder which is used to store cached values persistently.
 @param error Will be assigned if something went wrong during initializing.
 @return An instance of MoabCache
 */
- (nullable instancetype)initWithName:(NSString *)name error:(NSError *__autoreleasing *)error;

/**
 Instance's name.

 @return cache name
 */
- (NSString *)name;

/**
 Caches the object.

 @param object Object which is to be cached. It should conform to NSCoding protocol. Passing nil will delete corresponding object.
 @param key the key which should be used for the object above.
 */
- (void)setObject:(id<NSCoding>)object forKey:(NSString *)key;

/**
 Indicates whether object exists for the key or not.

 @param key The key of the object.
 @return Boolean indicating if an object is stored in the cache.
 */
- (BOOL)objectExistsForKey:(NSString *)key;

/**
 Returns an object for the corresponding key.

 @param key The key of the object.
 @return An object or nil if the object is not in the cache
 */
- (nullable id)objectForKey:(NSString *)key;

/**
 Removes an object from the cache.

 @param key Object's key
 */
- (void)removeObjectForKey:(NSString *)key;

/**
 Removes all objects from the cache and persistent store.
 */
- (void)removeAllObjects;

/**
 Removes all objects from in-memory cache.
 */
- (void)clearMemory;

/* Subscripting support */
- (void)setObject:(id)obj forKeyedSubscript:(NSString *)key;
- (nullable id)objectForKeyedSubscript:(NSString *)key;


/**
 Returnes object's file path.

 @param key The key of the object.
 @return If object exists, nil otherwise.
 @exception MoabCacheKeyIsNilException will be raised if the key provided is nil.
 */
- (nullable NSString *)pathForObjectForKey:(NSString *)key;


/**
 Removes all objects from names, Only by NSCachesDirectory document.
 */
+ (void)removeAllNameCache;

/**
 Removes all objects from names, Only by NSCachesDirectory document.

 @param directory Removes by NSSearchPathDirectory document.
 */
+ (void)removeAllNameCacheBySearchPathDirectory:(NSSearchPathDirectory) directory;

/**
 Statistics cache folder size

 @return size is long long
 */
+ (long long)statisticsCacheFolderSize;

@end
NS_ASSUME_NONNULL_END
