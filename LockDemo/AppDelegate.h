//
//  AppDelegate.h
//  LockDemo
//
//  Created by henghao.jiao on 2018/4/11.
//  Copyright © 2018年 liu.lisa. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong) NSPersistentContainer *persistentContainer;

- (void)saveContext;


@end

