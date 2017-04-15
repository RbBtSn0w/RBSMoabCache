//
//  AppDelegate.h
//  SWMoabCacheExample
//
//  Created by Snow Wu on 4/15/17.
//  Copyright © 2017 RbBtSn0w. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong) NSPersistentContainer *persistentContainer;

- (void)saveContext;


@end

