//
//  ViewController.m
//  LockDemo
//
//  Created by henghao.jiao on 2018/4/11.
//  Copyright © 2018年 liu.lisa. All rights reserved.
//

#import "ViewController.h"
#import <os/lock.h>
#import <pthread.h>

os_unfair_lock_t lock = &(OS_UNFAIR_LOCK_INIT);

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)action1:(id)sender {
    //自旋锁已经不在安全，然后苹果又整出来个 os_unfair_lock_t, 解决了自旋锁优先级反转的问题
    //这边通过log打印可以看出，线程1和线程2可能都会抢占lock的优先权，其中任何一个抢占成功后，除非解锁，另外一个才会得到lock
    //可以做实验，比如把线程1的unlock屏蔽，如果恰好是线程1抢得的优先权，那么线程2就永远不会被执行到，因为没有释放锁
    //线程1
    //    2018-04-11 17:11:17.151192+0800 LockDemo[10465:2932654] 线程2 准备上锁
    //    2018-04-11 17:11:17.151221+0800 LockDemo[10465:2932653] 线程1 准备上锁
    //    2018-04-11 17:11:21.153621+0800 LockDemo[10465:2932654] 线程2执行
    //    2018-04-11 17:11:21.153837+0800 LockDemo[10465:2932654] 线程2 解锁成功
    //    2018-04-11 17:11:21.153906+0800 LockDemo[10465:2932654] ----------------
    //    2018-04-11 17:11:25.156078+0800 LockDemo[10465:2932653] 线程1执行
    //    2018-04-11 17:11:25.156228+0800 LockDemo[10465:2932653] 线程1 解锁成功
    //    2018-04-11 17:11:25.156320+0800 LockDemo[10465:2932653] ----------------
    //
    //
    //
    //    2018-04-11 17:13:10.679207+0800 LockDemo[10492:2935732] 线程1 准备上锁
    //    2018-04-11 17:13:10.679207+0800 LockDemo[10492:2935733] 线程2 准备上锁
    //    2018-04-11 17:13:14.684497+0800 LockDemo[10492:2935732] 线程1执行
    //    2018-04-11 17:13:14.684677+0800 LockDemo[10492:2935732] 线程1 解锁成功
    //    2018-04-11 17:13:14.684765+0800 LockDemo[10492:2935732] ----------------
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"线程1 准备上锁");
        //如果lock没有解锁就又执行了上锁，那么就会造成死锁
        os_unfair_lock_lock(lock);
        sleep(4);
        NSLog(@"线程1执行");
        //可以做实验，比如把线程1的unlock屏蔽，如果恰好是线程1抢得的优先权，那么线程2就永远不会被执行到，因为没有释放锁
        os_unfair_lock_unlock(lock);
        NSLog(@"线程1 解锁成功");
        NSLog(@"----------------");
    });
    
    //线程2
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"线程2 准备上锁");
        os_unfair_lock_lock(lock);
        sleep(4);
        NSLog(@"线程2执行");
        os_unfair_lock_unlock(lock);
        NSLog(@"线程2 解锁成功");
        NSLog(@"----------------");
    });
}

- (IBAction)action2:(id)sender {
    dispatch_semaphore_t signal = dispatch_semaphore_create(1); //传入值必须 >=0, 若传入为0则阻塞线程并等待timeout,时间到后会执行其后的语句
    dispatch_time_t overTime = dispatch_time(DISPATCH_TIME_NOW, 3.0f * NSEC_PER_SEC);
    
    //    2018-04-11 17:21:53.478996+0800 LockDemo[10549:2946159] 线程1 等待ing
    //    2018-04-11 17:21:53.479009+0800 LockDemo[10549:2946078] 线程2 等待ing
    //    2018-04-11 17:21:53.479136+0800 LockDemo[10549:2946159] 线程1
    //    2018-04-11 17:21:53.479269+0800 LockDemo[10549:2946159] 线程1 发送信号
    //    2018-04-11 17:21:53.479275+0800 LockDemo[10549:2946078] 线程2
    //    2018-04-11 17:21:53.479338+0800 LockDemo[10549:2946159] --------------------------------------------------------
    //    2018-04-11 17:21:53.479346+0800 LockDemo[10549:2946078] 线程2 发送信号
    //线程1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"线程1 等待ing");
        dispatch_semaphore_wait(signal, overTime); //signal 值 -1
        NSLog(@"线程1");
        dispatch_semaphore_signal(signal); //signal 值 +1
        NSLog(@"线程1 发送信号");
        NSLog(@"--------------------------------------------------------");
    });
    
    //线程2
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"线程2 等待ing");
        dispatch_semaphore_wait(signal, overTime);
        NSLog(@"线程2");
        dispatch_semaphore_signal(signal);
        NSLog(@"线程2 发送信号");
    });
}

- (IBAction)action3:(id)sender {
    static pthread_mutex_t pLock;
    pthread_mutex_init(&pLock, NULL);
    //1.线程1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"线程1 准备上锁");
        pthread_mutex_lock(&pLock);
        sleep(3);
        NSLog(@"线程1执行");
        pthread_mutex_unlock(&pLock);
    });
    
    //1.线程2
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"线程2 准备上锁");
        pthread_mutex_lock(&pLock);
        NSLog(@"线程2执行");
        pthread_mutex_unlock(&pLock);
    });
    
}

- (IBAction)action4:(id)sender {
    //    经过上面几种例子，我们可以发现：加锁后只能有一个线程访问该对象，后面的线程需要排队，并且 lock 和 unlock 是对应出现的，同一线程多次 lock 是不允许的，而递归锁允许同一个线程在未释放其拥有的锁时反复对该锁进行加锁操作。会发现递归锁，上了几次锁，最后就会释放几次锁
    static pthread_mutex_t pLock;
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr); //初始化attr并且给它赋予默认
    pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE); //设置锁类型，这边是设置为递归锁
    pthread_mutex_init(&pLock, &attr);
    pthread_mutexattr_destroy(&attr); //销毁一个属性对象，在重新进行初始化之前该结构不能重新使用
    
    //1.线程1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        static void (^RecursiveBlock)(int);
        RecursiveBlock = ^(int value) {
            pthread_mutex_lock(&pLock);
            NSLog(@"上锁成功...");
            if (value >= 0) {
                NSLog(@"value: %d", value);
                RecursiveBlock(value - 1);
            }
            NSLog(@"开始解锁...");
            pthread_mutex_unlock(&pLock);
        };
        RecursiveBlock(5);
    });
    
}

- (IBAction)action5:(id)sender {
    //    NSLock
    //    lock、unlock：不多做解释，和上面一样
    //    trylock：能加锁返回 YES 并执行加锁操作，相当于 lock，反之返回 NO
    //    lockBeforeDate：这个方法表示会在传入的时间内尝试加锁，若能加锁则执行加锁操作并返回 YES，反之返回 N
    NSLock *lock = [NSLock new];
    //线程1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"线程1 尝试加速ing...");
        [lock lock];
        sleep(3);//睡眠5秒
        NSLog(@"线程1开始执行...");
        [lock unlock];
        NSLog(@"线程1解锁成功");
    });
    
    //线程2
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"线程2 尝试加速ing...");
        BOOL x =  [lock lockBeforeDate:[NSDate dateWithTimeIntervalSinceNow:4]];
        if (x) {
            NSLog(@"线程2开始执行...");
            [lock unlock];
        }else{
            NSLog(@"失败");
        }
    });
    
}

- (IBAction)action6:(id)sender {
    //    NSCondition
    //    看字面意思很好理解:
    //
    //    wait：进入等待状态
    //waitUntilDate:：让一个线程等待一定的时间
    //    signal：唤醒一个等待的线程
    //    broadcast：唤醒所有等待的线程
    
    
    //等待两秒后执行
    //    NSCondition *cLock = [NSCondition new];
    //    //线程1
    //    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    //        NSLog(@"start");
    //        [cLock lock];
    //        [cLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
    //        NSLog(@"线程1");
    //        [cLock unlock];
    //    });
    
    
    //唤醒一个线程
    //    NSCondition *cLock = [NSCondition new];
    //    //线程1
    //    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    //        [cLock lock];
    //        NSLog(@"线程1加锁成功");
    //        [cLock wait];
    //        NSLog(@"线程1执行...");
    //        [cLock unlock];
    //    });
    //
    //    //线程2
    //    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    //        [cLock lock];
    //        NSLog(@"线程2加锁成功");
    //        [cLock wait];
    //        NSLog(@"线程2执行...");
    //        [cLock unlock];
    //    });
    //
    //    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    //        sleep(2);
    //        NSLog(@"唤醒一个等待的线程");
    //        [cLock signal];
    //    });
    
    
    //唤醒所有的线程
    NSCondition *cLock = [NSCondition new];
    //线程1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [cLock lock];
        NSLog(@"线程1加锁成功");
        [cLock wait];
        NSLog(@"线程1执行...");
        [cLock unlock];
    });
    
    //线程2
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [cLock lock];
        NSLog(@"线程2加锁成功");
        [cLock wait];
        NSLog(@"线程2执行...");
        [cLock unlock];
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(2);
        NSLog(@"唤醒所有的线程");
        [cLock broadcast];
    });
    
}

- (IBAction)action7:(id)sender {
    NSRecursiveLock *rLock = [NSRecursiveLock new];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        static void (^RecursiveBlock)(int);
        RecursiveBlock = ^(int value) {
            [rLock lock];
            if (value > 0) {
                NSLog(@"线程%d", value);
                RecursiveBlock(value - 1);
            }
            //递归锁允许在不解锁的情况下多次加锁
            [rLock unlock];
        };
        RecursiveBlock(4);
    });
}

- (IBAction)action8:(id)sender {
    //线程1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @synchronized (self) {
            sleep(2);
            NSLog(@"线程1");
        }
    });
    
    //线程2
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @synchronized (self) {
            NSLog(@"线程2");
        }
    });
}

@end
