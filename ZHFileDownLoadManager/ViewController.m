//
//  ViewController.m
//  ZHFileDownLoadManager
//
//  Created by walen on 16/5/31.
//  Copyright © 2016年 walen. All rights reserved.
//

#import "ViewController.h"
#import "ZHFileDownLoadManager.h"

@interface ViewController ()

@property (nonatomic, strong) ZHFileDownLoadTask *downLoadTask;
@property (nonatomic, strong) ZHBackgroundFileDownLoadTask *backgroundDownLoadTask;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UIProgressView *backgroundProgressVeiw;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}
- (IBAction)startDownLoad:(id)sender {
    
    NSURL *url = [NSURL URLWithString:@"http://dlsw.baidu.com/sw-search-sp/soft/0c/25762/KugouMusicForMac.1395978517.dmg"];
    
    NSString *localFilePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:@"KugouMusicForMac.1395978517.dmg"];
    __weak typeof(self) weakSelf = self;
    self.downLoadTask = [[ZHFileDownLoadManager manager] downLoadWithUrl:url downLoadPath:localFilePath progressCallBack:^(ZHFileDownLoadTask *task, long long downLoadLength, long long totolLength) {
        weakSelf.progressView.progress = downLoadLength * 1.0 / totolLength;
    } completeCallBack:^(ZHFileDownLoadTask *task, NSString *localFilePath, NSError *error) {
        if (error) {
            NSLog(@"downLoad failed error = %@", error.localizedDescription);
        }
        else
        {
            NSLog(@"downLoad sucess localFilePath = %@", localFilePath);
        }
    }];
    
    [self.downLoadTask resume];
}

- (IBAction)stopDownLoad:(id)sender {
    [self.downLoadTask cancel];
}

- (IBAction)startBackgroundDownload:(id)sender {
    NSURL *url = [NSURL URLWithString:@"http://dlsw.baidu.com/sw-search-sp/soft/0c/25762/KugouMusicForMac.1395978517.dmg"];
    
    __weak typeof(self) weakSelf = self;
    self.backgroundDownLoadTask = [[ZHFileDownLoadManager manager] backgroundDownLoadWithUrl:url progressCallBack:^(ZHBackgroundFileDownLoadTask *task, long long downLoadLength, long long totolLength) {
        weakSelf.backgroundProgressVeiw.progress = downLoadLength * 1.0 / totolLength;
    } completeCallBack:^(ZHBackgroundFileDownLoadTask *task, NSURL *location, NSError *error) {
        if (error) {
            NSLog(@"downLoad failed error = %@", error.localizedDescription);
        }
        else
        {
            NSLog(@"downLoad sucess localFilePath = %@", location);
        }
    }];
    [self.backgroundDownLoadTask resume];
}
- (IBAction)stopBackgroundDownLoad:(id)sender {
    [self.backgroundDownLoadTask cancel];
}

- (void)dealloc
{
    NSLog(@"dealloc %@", self);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
