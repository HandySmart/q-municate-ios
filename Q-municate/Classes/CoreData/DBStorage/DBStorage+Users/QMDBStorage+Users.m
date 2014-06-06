//
//  QMDBStorage+Users.m
//  Q-municate
//
//  Created by Andrey on 04.06.14.
//  Copyright (c) 2014 Quickblox. All rights reserved.
//

#import "QMDBStorage+Users.h"
#import "ModelIncludes.h"

#define CONTAINS(attrName, attrVal) [NSPredicate predicateWithFormat:@"self.%K CONTAINS %@", attrName, attrVal]
#define LIKE(attrName, attrVal) [NSPredicate predicateWithFormat:@"%K like %@", attrName, attrVal]
#define LIKE_C(attrName, attrVal) [NSPredicate predicateWithFormat:@"%K like[c] %@", attrName, attrVal]
#define IS(attrName, attrVal) [NSPredicate predicateWithFormat:@"%K == %@", attrName, attrVal]

@interface QMDBStorage ()

<NSFetchedResultsControllerDelegate>

@end

@implementation QMDBStorage (Users)

#pragma mark - Public methods

- (void)cachedQbUsers:(QMDBCollectionBlock)qbUsers {
    
    [self async:^(NSManagedObjectContext *context) {
        
        NSArray *allUsers = [self allUsersInContext:context];
        DO_AT_MAIN(qbUsers(allUsers));
        
    }];
}

- (void)cacheUsers:(NSArray *)users finish:(QMDBFinishBlock)finish {
    
    __weak __typeof(self)weakSelf = self;
    
    [self async:^(NSManagedObjectContext *context) {
        [weakSelf mergeQBUsers:users inContext:context finish:finish];
    }];
}

#pragma mark - Private methods

- (NSArray *)allUsersInContext:(NSManagedObjectContext *)context {
    
    NSArray *cdUsers = [CDUsers MR_findAllInContext:context];
    NSArray *result = (cdUsers.count == 0) ? @[] : [self qbUsersWithcdUsers:cdUsers];
    
    return result;
}

- (NSArray *)qbUsersWithcdUsers:(NSArray *)cdUsers {
    
    NSMutableArray *qbUsers = [NSMutableArray arrayWithCapacity:cdUsers.count];
    
    for (CDUsers *user in cdUsers) {
        QBUUser *qbUser = [user toQBUUser];
        [qbUsers addObject:qbUser];
    }
    
    return qbUsers;
}

#define TEST_DUBLICATE_CASE

#ifdef TEST_DUBLICATE_CASE

- (void)checkDublicateInQBUsers:(NSArray *)qbUsers {
    
    NSMutableSet *ids = [NSMutableSet set];
    
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(QBUUser *qbUser, NSDictionary *bindings) {
        
        NSNumber *userId = @(qbUser.externalUserID);
        BOOL contains = [ids containsObject:userId];
        
        if (!contains) {
            [ids addObject:userId];
        }
        return contains;
    }];
    
    //TODO: Need add version checker
    NSArray *dublicates = [qbUsers filteredArrayUsingPredicate:predicate];
    NSAssert(dublicates.count == 0, @"Collectin have dublicates");
}

#endif

- (void)mergeQBUsers:(NSArray *)qbUsers inContext:(NSManagedObjectContext *)context finish:(QMDBFinishBlock)finish {
    
#ifdef TEST_DUBLICATE_CASE
    [self checkDublicateInQBUsers:qbUsers];
#endif
    
    NSArray *allUsers = [self allUsersInContext:context];
    
    NSMutableArray *toInsert = [NSMutableArray array];
    NSMutableArray *toUpdate = [NSMutableArray array];
    NSMutableArray *toDelete = [NSMutableArray arrayWithArray:allUsers];
    
    //Update/Insert/Delete
    
    for (QBUUser *user in qbUsers) {
        
        NSInteger idx = [allUsers indexOfObject:user];
        
        if (idx == NSNotFound) {
            
            QBUUser *toUpdateUser = nil;
            
            for (QBUUser *candidateToUpdate in allUsers) {
                
                if (candidateToUpdate.externalUserID == user.externalUserID) {
                    
                    toUpdateUser = user;
                    [toDelete removeObject:candidateToUpdate];
                    
                    break;
                }
            }
            
            if (toUpdateUser) {
                [toUpdate addObject:toUpdateUser];
            } else {
                [toInsert addObject:user];
            }
            
        } else {
            [toDelete removeObject:user];
        }
    }
    
    __weak __typeof(self)weakSelf = self;
    [self async:^(NSManagedObjectContext *context) {
        
        if (toUpdate.count != 0) {
            [weakSelf updateQBUsers:toUpdate inContext:context];
        }
        
        if (toInsert.count != 0) {
            [weakSelf insertQBUsers:toInsert inContext:context];
        }
        
        if (toDelete.count != 0) {
            [weakSelf deleteQBUsers:toDelete inContext:context];
        }
        
        NSLog(@"Users in cahce %d", allUsers.count);
        NSLog(@"Users to insert %d", toInsert.count);
        NSLog(@"Users to update %d", toUpdate.count);
        NSLog(@"Users to delete %d", toDelete.count);
        
        [weakSelf save:finish];
    }];
}

- (void)insertQBUsers:(NSArray *)qbUsers inContext:(NSManagedObjectContext *)context {
    
    for (QBUUser *qbUser in qbUsers) {
        CDUsers *user = [CDUsers MR_createEntityInContext:context];
        [user updateWithQBUser:qbUser];
    }
}

- (void)deleteQBUsers:(NSArray *)qbUsers inContext:(NSManagedObjectContext *)context {
    
    for (QBUUser *qbUser in qbUsers) {
        CDUsers *userToDelete = [CDUsers MR_findFirstWithPredicate:IS(@"externalUserId", @(qbUser.externalUserID))
                                                         inContext:context];
        [userToDelete MR_deleteEntityInContext:context];
    }
}

- (void)updateQBUsers:(NSArray *)qbUsers inContext:(NSManagedObjectContext *)context {
    
    for (QBUUser *qbUser in qbUsers) {
        CDUsers *userToUpdate = [CDUsers MR_findFirstWithPredicate:IS(@"externalUserId", @(qbUser.externalUserID))
                                                         inContext:context];
        [userToUpdate updateWithQBUser:qbUser];
    }
}

@end