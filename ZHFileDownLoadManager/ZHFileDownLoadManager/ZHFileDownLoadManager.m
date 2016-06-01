//
//  ZHFileDownLoadManager.m
//  ZHFileDownLoadManager
//
//  Created by walen on 16/5/31.
//  Copyright © 2016年 walen. All rights reserved.
//

#import "ZHFileDownLoadManager.h"
#import <objc/runtime.h>
#import <CommonCrypto/CommonDigest.h>

@interface NSURLSessionTask (DownLoadInfo)

@property (nonatomic, strong) ZHFileDownLoadTask *downLoadTask;
@property (nonatomic, strong) ZHBackgroundFileDownLoadTask *backgroundDownLoadTask;

@end

@implementation NSURLSessionTask (DownLoadInfo)

- (void)setDownLoadTask:(ZHFileDownLoadTask *)downLoadTask
{
    objc_setAssociatedObject(self, @selector(downLoadTask), downLoadTask, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (ZHFileDownLoadTask *)downLoadTask
{
    id obj = objc_getAssociatedObject(self, @selector(downLoadTask));
    if (!object_getClass(obj)) {
        obj = nil;
    }
    return obj;
}

- (void)setBackgroundDownLoadTask:(ZHBackgroundFileDownLoadTask *)backgroundDownLoadTask
{
    objc_setAssociatedObject(self, @selector(backgroundDownLoadTask), backgroundDownLoadTask, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (ZHBackgroundFileDownLoadTask *)backgroundDownLoadTask
{
    id obj = objc_getAssociatedObject(self, @selector(backgroundDownLoadTask));
    if (!object_getClass(obj)) {
        obj = nil;
    }
    return obj;
}

@end

@interface ZHFileDownLoadTask()

@property (nonatomic, assign, readwrite) ZHFileDownLoadTaskStatus status;
@property (nonatomic, copy, readwrite) NSURL *remoteFileUrl;
@property (nonatomic, copy, readwrite) NSString *localFilePath;
@property (nonatomic, assign) long long downLoadedLength;
@property (nonatomic, assign, readwrite) long long totolLength;
@property (nonatomic, copy, readwrite) DownLoadProgressCallBack progressCallBack;
@property (nonatomic, copy, readwrite) DownLoadCompleteCallBack completeCallBack;

@property (nonatomic, weak) NSURLSessionDataTask *dataTask;

- (instancetype)initWithUrl:(NSURL *)remoteFileUrl downLoadPath:(NSString *)downLoadPath progressCallBack:(DownLoadProgressCallBack)progressCallBack completeCallBack:(DownLoadCompleteCallBack)completeCallBack;

@end

@implementation ZHFileDownLoadTask

- (instancetype)initWithUrl:(NSURL *)remoteFileUrl downLoadPath:(NSString *)downLoadPath progressCallBack:(DownLoadProgressCallBack)progressCallBack completeCallBack:(DownLoadCompleteCallBack)completeCallBack
{
    if (self = [super init]) {
        _remoteFileUrl = remoteFileUrl;
        self.localFilePath = downLoadPath.copy;
        _progressCallBack = [progressCallBack copy];
        _completeCallBack = [completeCallBack copy];
    }
    return self;
}
- (void)resume
{
    [[ZHFileDownLoadManager manager].downLoadQueue addOperationWithBlock:^{
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.remoteFileUrl];
        //设置请求头
        [request setValue:@"application/json;text/plain;text/javascript;text/json;text/html" forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"*/*" forHTTPHeaderField:@"Accept"];
        
        if (self.downLoadedLength > 0) {
            NSString *requestRange = [NSString stringWithFormat:@"bytes=%llu-", self.downLoadedLength];
            [request setValue:requestRange forHTTPHeaderField:@"Range"];
        }
        
        NSURLSessionDataTask *dataTask = [[ZHFileDownLoadManager manager].session dataTaskWithRequest:request];
        
        self.dataTask = dataTask;
        
        dataTask.downLoadTask = self;
        
        [self.dataTask resume];
    }];
}

- (void)cancel
{
    [[ZHFileDownLoadManager manager].downLoadQueue addOperationWithBlock:^{
        [self.dataTask cancel];
    }];
}

- (ZHFileDownLoadTaskStatus)status
{
    switch (self.dataTask.state) {
        case NSURLSessionTaskStateRunning:
            return ZHFileDownLoadTaskStatusRunning;
            break;
        case NSURLSessionTaskStateSuspended:
            return ZHFileDownLoadTaskStatusSuspended;
            break;
        case NSURLSessionTaskStateCanceling:
            return ZHFileDownLoadTaskStatusCanceling;
            break;
        case NSURLSessionTaskStateCompleted:
            return ZHFileDownLoadTaskStatusRunning;
            break;
            
        default:
            return ZHFileDownLoadTaskStatusCompleted;
            break;
    }
}
- (void)setLocalFilePath:(NSString *)localFilePath
{
    _localFilePath = localFilePath.copy;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:localFilePath]) {
        if (![fileManager createFileAtPath:localFilePath contents:nil attributes:nil]) {
            NSLog(@"create file failed!path = %@", localFilePath);
            [self.dataTask cancel];
        }
    }
    
    self.downLoadedLength = [self fileSizeForPath:localFilePath];
}

- (void)receivedData:(NSData *)data
{
    if (!self.localFilePath) {
        NSLog(@"file at local path doesn't exist!");
        return;
    }
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:self.localFilePath];
    [fileHandle seekToEndOfFile];
    
    [fileHandle writeData:data];
    [fileHandle closeFile];
    
    self.downLoadedLength += data.length;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.progressCallBack) {
            self.progressCallBack(self, self.downLoadedLength, self.totolLength);
        }
    });
    
    if (self.downLoadedLength == self.dataTask.countOfBytesExpectedToReceive && self.completeCallBack) {
        if (self.completeCallBack) {
            self.completeCallBack(self, self.localFilePath, nil);
            self.completeCallBack = nil;
        }
    }
}

- (long long)fileSizeForPath:(NSString *)path {
    long long fileSize = 0;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:path]) {
        NSError *error = nil;
        NSDictionary *fileDict = [fileManager attributesOfItemAtPath:path error:&error];
        if (!error && fileDict) {
            fileSize = [fileDict fileSize];
        }
    }
    return fileSize;
}

@end

@interface ZHBackgroundFileDownLoadTask()

@property (nonatomic, assign, readwrite) ZHFileDownLoadTaskStatus status;
@property (nonatomic, copy, readwrite) NSURL *remoteFileUrl;
@property (nonatomic, assign) long long downLoadedLength;
@property (nonatomic, assign, readwrite) long long totolLength;
@property (nonatomic, copy, readwrite) BackgroundDownLoadProgressCallBack progressCallBack;
@property (nonatomic, copy, readwrite) BackgroundDownLoadCompleteCallBack completeCallBack;

@property (nonatomic, strong) NSData *resumeData;

@property (nonatomic, weak) NSURLSessionDownloadTask *downLoadTask;

- (instancetype)initWithUrl:(NSURL *)remoteFileUrl progressCallBack:(BackgroundDownLoadProgressCallBack)progressCallBack completeCallBack:(BackgroundDownLoadCompleteCallBack)completeCallBack;

@end

@implementation ZHBackgroundFileDownLoadTask

- (instancetype)initWithUrl:(NSURL *)remoteFileUrl progressCallBack:(BackgroundDownLoadProgressCallBack)progressCallBack completeCallBack:(BackgroundDownLoadCompleteCallBack)completeCallBack
{
    if (self = [super init]) {
        self.remoteFileUrl = remoteFileUrl;
        _progressCallBack = [progressCallBack copy];
        _completeCallBack = [completeCallBack copy];
    }
    return self;
}

- (void)resume
{
    [[ZHFileDownLoadManager manager].downLoadQueue addOperationWithBlock:^{
        
        self.resumeData = [self resumeDataForUrl:self.remoteFileUrl];
        NSURLSessionDownloadTask *downLoadTask = nil;
        
        NSURLSession *session = [ZHFileDownLoadManager manager].session;
        if (self.resumeData) {
            downLoadTask = [session downloadTaskWithResumeData:self.resumeData];
        }
        else
        {
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.remoteFileUrl];
            //设置请求头
            [request setValue:@"application/json;text/plain;text/javascript;text/json;text/html" forHTTPHeaderField:@"Content-Type"];
            [request setValue:@"*/*" forHTTPHeaderField:@"Accept"];
            downLoadTask = [session downloadTaskWithRequest:request];
        }
        
        self.downLoadTask = downLoadTask;
        
        downLoadTask.backgroundDownLoadTask = self;
        
        [self removeResumeDataForUrl:self.remoteFileUrl];
        [self.downLoadTask resume];
    }];
}
- (void)cancel
{
    [[ZHFileDownLoadManager manager].downLoadQueue addOperationWithBlock:^{
        [self.downLoadTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
            [self saveResumeData:resumeData forUrl:self.remoteFileUrl];
        }];
    }];
}

- (NSString *)resumeDataCachedFileNameForKey:(NSString *)key {
    const char *str = [key UTF8String];
    if (str == NULL) {
        str = "";
    }
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSString *filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%@",
                          r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10],
                          r[11], r[12], r[13], r[14], r[15], [[key pathExtension] isEqualToString:@""] ? @"" : [NSString stringWithFormat:@".%@", [key pathExtension]]];
    
    return filename;
}

- (NSString *)resumeDataCacheDirectory
{
    return [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:@"ZHFileDownLoadManagerDirectory"];
}
- (NSString *)resumeCachedPathForKey:(NSString *)key
{
    return [[self resumeDataCacheDirectory] stringByAppendingPathComponent:[self resumeDataCachedFileNameForKey:key]];
}

- (NSData *)resumeDataForUrl:(NSURL *)url
{
    NSString *resumeFilePath = [self resumeCachedPathForKey:url.absoluteString];
    return [NSData dataWithContentsOfFile:resumeFilePath];
}

- (void)saveResumeData:(NSData *)resumeData forUrl:(NSURL *)url
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *resumeDataCachedDirectory = [self resumeDataCacheDirectory];
    if (![fileManager fileExistsAtPath:resumeDataCachedDirectory isDirectory:nil]) {
        if (![fileManager createDirectoryAtPath:resumeDataCachedDirectory withIntermediateDirectories:NO attributes:nil error:nil]) {
            NSLog(@"createDirectoryAtPath failed directory = %@", resumeDataCachedDirectory);
            return;
        };
    }
    NSString *resumeDataCachedPath = [self resumeCachedPathForKey:url.absoluteString];
    if (![fileManager createFileAtPath:resumeDataCachedPath contents:resumeData attributes:nil]) {
        NSLog(@"createFileAtPath failed path = %@", resumeDataCachedPath);
        return;
    }
}

- (void)removeResumeDataForUrl:(NSURL *)url
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *filePath = [self resumeCachedPathForKey:url.absoluteString];
    [fileManager removeItemAtPath:filePath error:nil];
}

@end

@interface ZHFileDownLoadManager ()<NSURLSessionDataDelegate, NSURLSessionDownloadDelegate>

@property (nonatomic, assign, readwrite) NSUInteger currentDownLoadCount;

@end

@implementation ZHFileDownLoadManager

static ZHFileDownLoadManager *instance = nil;

+ (instancetype)allocWithZone:(struct _NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [super allocWithZone:zone];
    });
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _downLoadQueue = [[NSOperationQueue alloc] init];
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringCacheData;
        _session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:_downLoadQueue];
    }
    return self;
}

+ (instancetype)manager
{
    return instance ? : [[self alloc] init];
}

- (NSUInteger)maxDownLoadConcurrentCount
{
    return self.downLoadQueue.maxConcurrentOperationCount;
}

- (void)setMaxDownLoadConcurrentCount:(NSUInteger)maxDownLoadConcurrentCount
{
    self.downLoadQueue.maxConcurrentOperationCount = maxDownLoadConcurrentCount;
}

- (NSUInteger)currentDownLoadCount
{
    return self.downLoadQueue.operationCount;
}

- (ZHFileDownLoadTask *)downLoadWithUrl:(NSURL *)remoteFileUrl downLoadPath:(NSString *)downLoadPath progressCallBack:(DownLoadProgressCallBack)progressCallBack completeCallBack:(DownLoadCompleteCallBack)completeCallBack
{
    NSParameterAssert(remoteFileUrl);
    NSParameterAssert(downLoadPath);
    
    ZHFileDownLoadTask *downLoadTask = [[ZHFileDownLoadTask alloc] initWithUrl:remoteFileUrl downLoadPath:downLoadPath progressCallBack:progressCallBack completeCallBack:completeCallBack];
    
    return downLoadTask;
}

- (ZHBackgroundFileDownLoadTask *)backgroundDownLoadWithUrl:(NSURL *)remoteFileUrl progressCallBack:(BackgroundDownLoadProgressCallBack)progressCallBack completeCallBack:(BackgroundDownLoadCompleteCallBack)completeCallBack
{
    NSParameterAssert(remoteFileUrl);
    
    ZHBackgroundFileDownLoadTask *backgroundDownLoadTask = [[ZHBackgroundFileDownLoadTask alloc] initWithUrl:remoteFileUrl progressCallBack:progressCallBack completeCallBack:completeCallBack];
    
    return backgroundDownLoadTask;
}

#pragma mark -- NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error
{
    if ([task isKindOfClass:[NSURLSessionDataTask class]]) {
        ZHFileDownLoadTask *downLoadTask = task.downLoadTask;
        NSAssert(downLoadTask, @"downLoadTask shouldn't be nil");
        
        if (!downLoadTask) {
            NSLog(@"downLoadTask doesn't exist!");
            return;
        }
        if (!error && task.state == NSURLSessionTaskStateCompleted && downLoadTask.downLoadedLength >= downLoadTask.totolLength) {
            if (downLoadTask.completeCallBack) {
                downLoadTask.completeCallBack(downLoadTask, downLoadTask.localFilePath, nil);
                downLoadTask.completeCallBack = nil;
            }
        }
        else if (error)
        {
            if (downLoadTask.completeCallBack) {
                downLoadTask.completeCallBack(downLoadTask, downLoadTask.localFilePath, error);
                downLoadTask.completeCallBack = nil;
            }
        }
    }
    else if ([task isKindOfClass:[NSURLSessionDownloadTask class]])
    {
        ZHBackgroundFileDownLoadTask *downLoadTask = task.backgroundDownLoadTask;
        NSAssert(downLoadTask, @"downLoadTask shouldn't be nil");
        if (!downLoadTask) {
            NSLog(@"downLoadTask doesn't exist!");
            return;
        }
        if (error) {
            NSData *resumeData = error.userInfo[NSURLSessionDownloadTaskResumeData];
            
            if (resumeData) {
                //如果失败 就保存resumeData
                [downLoadTask saveResumeData:resumeData forUrl:downLoadTask.remoteFileUrl];
                
                if (downLoadTask.completeCallBack) {
                    downLoadTask.completeCallBack(downLoadTask, nil, error);
                    downLoadTask.completeCallBack = nil;
                }
            }
        }
    }
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
    ZHFileDownLoadTask *downLoadTask = dataTask.downLoadTask;
    NSAssert(downLoadTask, @"downLoadTask shouldn't be nil");
    
    if (!downLoadTask) {
        NSLog(@"downLoadTask doesn't exist!");
        return;
    }
    if (downLoadTask.totolLength <= 0) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)dataTask.response;
        if ([httpResponse respondsToSelector:@selector(allHeaderFields)]) {
            NSDictionary *headerDict = httpResponse.allHeaderFields;
            NSString *range = headerDict[@"Content-Range"];
            NSString *contentLength = headerDict[@"Content-Length"];
            if (range) {
                NSArray *rangeArr = [range componentsSeparatedByString:@"/"];
                downLoadTask.totolLength = [rangeArr.lastObject longLongValue];
            }
            else if(contentLength)
            {
                downLoadTask.totolLength = [contentLength longLongValue];
            }
        }
    }
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location
{
    ZHBackgroundFileDownLoadTask *backgroundDownLoadTask = downloadTask.backgroundDownLoadTask;
    NSAssert(backgroundDownLoadTask, @"backgroundDownLoadTask shouldn't be nil");
    
    if (!backgroundDownLoadTask) {
        NSLog(@"downLoadTask doesn't exist!");
        return;
    }
    
    if (backgroundDownLoadTask.completeCallBack) {
        backgroundDownLoadTask.completeCallBack(backgroundDownLoadTask, location, nil);
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    NSLog(@"downloadTask bytesWritten = %@, totalBytesWritten = %@, totalBytesExpectedToWrite = %@", @(bytesWritten), @(totalBytesWritten), @(totalBytesExpectedToWrite));
    
    ZHBackgroundFileDownLoadTask *backgroundDownLoadTask = downloadTask.backgroundDownLoadTask;
    NSAssert(backgroundDownLoadTask, @"backgroundDownLoadTask shouldn't be nil");
    
    if (!backgroundDownLoadTask) {
        return;
    }
    backgroundDownLoadTask.downLoadedLength += bytesWritten;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (backgroundDownLoadTask.progressCallBack) {
            backgroundDownLoadTask.progressCallBack(backgroundDownLoadTask, totalBytesWritten, totalBytesExpectedToWrite);
        }
    });
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didResumeAtOffset:(int64_t)fileOffset
expectedTotalBytes:(int64_t)expectedTotalBytes
{
    ZHBackgroundFileDownLoadTask *backgroundDownLoadTask = downloadTask.backgroundDownLoadTask;
    NSAssert(backgroundDownLoadTask, @"backgroundDownLoadTask shouldn't be nil");
    
    if (!backgroundDownLoadTask) {
        return;
    }
    backgroundDownLoadTask.downLoadedLength = fileOffset;
    backgroundDownLoadTask.totolLength = expectedTotalBytes;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (backgroundDownLoadTask.progressCallBack) {
            backgroundDownLoadTask.progressCallBack(backgroundDownLoadTask, fileOffset, expectedTotalBytes);
        }
    });
}

@end
