//
//  QMChatDialogsService.m
//  Qmunicate
//
//  Created by Andrey on 02.07.14.
//  Copyright (c) 2014 Quickblox. All rights reserved.
//

#import "QMChatDialogsService.h"
#import "QBEchoObject.h"


@interface QMChatDialogsService()

@property (strong, nonatomic) NSMutableDictionary *dialogs;
@property (strong, nonatomic) NSMutableDictionary *chatRooms;

@end

@implementation QMChatDialogsService

- (void)start {
    
    self.dialogs = [NSMutableDictionary dictionary];
    self.chatRooms = [NSMutableDictionary dictionary];
}

- (void)destroy {
    
    [self.dialogs removeAllObjects];
    [self.chatRooms removeAllObjects];
}

- (void)fetchAllDialogs:(QBDialogsPagedResultBlock)completion {
    
    [QBChat dialogsWithDelegate:[QBEchoObject instance] context:[QBEchoObject makeBlockForEchoObject:completion]];
}

- (void)createChatDialog:(QBChatDialog *)chatDialog completion:(QBChatDialogResultBlock)completion {
    
	[QBChat createDialog:chatDialog delegate:[QBEchoObject instance] context:[QBEchoObject makeBlockForEchoObject:completion]];
}

- (void)updateChatDialogWithID:(NSString *)dialogID extendedRequest:(NSMutableDictionary *)extendedRequest completion:(QBChatDialogResultBlock)completion {
    
    [QBChat updateDialogWithID:dialogID
               extendedRequest:extendedRequest
                      delegate:[QBEchoObject instance]
                       context:[QBEchoObject makeBlockForEchoObject:completion]];
}

- (void)addDialogs:(NSArray *)dialogs {
    
    for (QBChatDialog *chatDialog in dialogs) {
        [self addDialogToHistory:chatDialog];
    }
}

- (QBChatDialog *)chatDialogWithID:(NSString *)dialogID {
    return self.dialogs[dialogID];
}

- (void)addDialogToHistory:(QBChatDialog *)chatDialog {
    
    //If type is equal group then need join room
    if (chatDialog.type == QBChatDialogTypeGroup) {
        
        NSString *roomJID = chatDialog.roomJID;
        NSAssert(roomJID, @"Need update this case");
        
        QBChatRoom *existRoom = self.chatRooms[roomJID];
        
        if (!existRoom) {
            QBChatRoom *chatRoom = [[QBChatRoom alloc] initWithRoomJID:roomJID];
            [chatRoom joinRoomWithHistoryAttribute:@{@"maxstanzas": @"0"}];
            self.chatRooms[roomJID] = chatRoom;
        }
        
    } else if (chatDialog.type == QBChatDialogTypePrivate) {
        
    }
    
    self.dialogs[chatDialog.ID] = chatDialog;
}

- (NSArray *)dialogHistory {
    return [self.dialogs allValues];
}

- (QBChatDialog *)privateDialogWithOpponentID:(NSUInteger)opponentID {

    NSString *substring = [NSString stringWithFormat:@"%d", opponentID];
    NSArray *allDialogs = [self dialogHistory];
    
    NSPredicate *predicate =
    [NSPredicate predicateWithFormat:@"SELF.type == %d AND SELF.occupantIDs CONTAINS[cd] %@", QBChatDialogTypePrivate, substring];
    
    NSArray *result = [allDialogs filteredArrayUsingPredicate:predicate];
    QBChatDialog *dialog = result.firstObject;
    
    return dialog;
}

- (QBChatRoom *)chatRoomWithRoomJID:(NSString *)roomJID {
    return self.chatRooms[roomJID];
}

- (void)updateChatDialogForChatMessage:(QBChatMessage *)chatMessage {
    
    NSString *roomJID = chatMessage.customParameters[@"xmpp_room_jid"];
    
    QBChatDialog *dialog = self.dialogs[roomJID];
    if (dialog == nil) {
        NSAssert(!dialog, @"Dialog you are looking for not found.");
        return;
    }
    
    dialog.name = chatMessage.customParameters[@"name"];
    
    NSString *occupantsIDs = chatMessage.customParameters[@"occupants_ids"];
    dialog.occupantIDs = [occupantsIDs componentsSeparatedByString:@","];
}


@end
