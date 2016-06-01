//
//  ZHFileDownLoadManager.h
//  ZHFileDownLoadManager
//
//  Created by walen on 16/5/31.
//  Copyright © 2016年 walen. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ZHFileDownLoadTask;
@class ZHBackgroundFileDownLoadTask;

typedef void(^DownLoadProgressCallBack)(ZHFileDownLoadTask *task, long long downLoadLength, long long totolLength);
typedef void(^DownLoadCompleteCallBack)(ZHFileDownLoadTask *task, NSString *localFilePath, NSError *error);

typedef void(^BackgroundDownLoadProgressCallBack)(ZHBackgroundFileDownLoadTask *task, long long downLoadLength, long long totolLength);
typedef void(^BackgroundDownLoadCompleteCallBack)(ZHBackgroundFileDownLoadTask *task, NSURL *location, NSError *error);

typedef NS_ENUM(NSUInteger, ZHFileDownLoadTaskStatus) {
    ZHFileDownLoadTaskStatusRunning = 0,
    ZHFileDownLoadTaskStatusSuspended,
    ZHFileDownLoadTaskStatusCanceling,
    ZHFileDownLoadTaskStatusCompleted,
};

@interface ZHFileDownLoadTask : NSObject

@property (nonatomic, assign, readonly) ZHFileDownLoadTaskStatus status;
@property (nonatomic, copy, readonly) NSURL *remoteFileUrl;
@property (nonatomic, assign, readonly) long long totolLength;
@property (nonatomic, assign, readonly) long long downLoadedLength;

@property (nonatomic, copy, readonly) DownLoadProgressCallBack progressCallBack;
@property (nonatomic, copy, readonly) DownLoadCompleteCallBack completeCallBack;

- (void)resume;
- (void)cancel;

@end

@interface ZHBackgroundFileDownLoadTask : NSObject

@property (nonatomic, assign, readonly) ZHFileDownLoadTaskStatus status;
@property (nonatomic, copy, readonly) NSURL *remoteFileUrl;
@property (nonatomic, assign, readonly) long long totolLength;
@property (nonatomic, assign, readonly) long long downLoadedLength;

@property (nonatomic, copy, readonly) BackgroundDownLoadProgressCallBack progressCallBack;
@property (nonatomic, copy, readonly) BackgroundDownLoadCompleteCallBack completeCallBack;

- (void)resume;
- (void)cancel;

@end

@interface ZHFileDownLoadManager : NSObject

+ (instancetype)manager;

@property (nonatomic, strong, readonly) NSOperationQueue *downLoadQueue;
@property (nonatomic, strong, readonly) NSURLSession *session;

@property (nonatomic, assign) NSUInteger maxDownLoadConcurrentCount;
@property (nonatomic, assign, readonly) NSUInteger currentDownLoadCount;

/**
 *  使用dataTask的方式来下载 不可后台下载
 *
 *  @param remoteFileUrl    文件的服务器地址
 *  @param downLoadPath     要下载的路径
 *  @param progressCallBack 下载进度回调
 *  @param completeCallBack 完成下载的回调
 *
 *  @return ZHFileDownLoadTask 实例
 */
- (ZHFileDownLoadTask *)downLoadWithUrl:(NSURL *)remoteFileUrl downLoadPath:(NSString *)downLoadPath progressCallBack:(DownLoadProgressCallBack)progressCallBack completeCallBack:(DownLoadCompleteCallBack)completeCallBack;

/**
 *  使用downloadTask的方式来下载 可后台下载
 *
 *  @param remoteFileUrl    文件的服务器地址
 *  @param progressCallBack 下载进度回调
 *  @param completeCallBack 完成下载的回调  需要在此block内部搬运文件到最终位置
 *
 *  @return ZHBackgroundFileDownLoadTask 实例
 */
- (ZHBackgroundFileDownLoadTask *)backgroundDownLoadWithUrl:(NSURL *)remoteFileUrl progressCallBack:(BackgroundDownLoadProgressCallBack)progressCallBack completeCallBack:(BackgroundDownLoadCompleteCallBack)completeCallBack;

@end
