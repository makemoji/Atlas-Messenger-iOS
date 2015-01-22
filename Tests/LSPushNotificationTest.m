//
//  LSPushNotificationTest.m
//  LayerSample
//
//  Created by Kevin Coleman on 1/15/15.
//  Copyright (c) 2015 Layer, Inc. All rights reserved.
//

#import "KIFTestCase.h"
#import <KIF/KIF.h>
#import "KIFSystemTestActor+ViewControllerActions.h"
#import <XCTest/XCTest.h>

#import "LSApplicationController.h"
#import "LSTestInterface.h"
#import "LSAuthenticationViewController.h"
#import "LSTestUser.h"
#import "LSUtilities.h"

@interface LSPushNotificationTest : KIFTestCase

@property (nonatomic) LSTestInterface *testInterface;
@property (nonatomic) NSMutableArray *layerClients;
@property (nonatomic) NSUInteger messageCount;
@property (nonatomic) dispatch_queue_t messageQueue;

@end

@implementation LSPushNotificationTest

- (void)setUp
{
    [super setUp];
    
    LSApplicationController *applicationController =  [(LSAppDelegate *)[[UIApplication sharedApplication] delegate] applicationController];
    self.testInterface = [LSTestInterface testInterfaceWithApplicationController:applicationController];
    [self.testInterface deleteContacts];
    
    [self.testInterface registerAndAuthenticateTestUser:[LSTestUser testUserWithNumber:10]];
    
    self.layerClients = [self instantiateLayerClientsWithCount:5];
    self.messageCount = 0;
    self.messageQueue = dispatch_queue_create(NULL, DISPATCH_QUEUE_CONCURRENT);
}

- (void)tearDown
{
    [self.testInterface logoutIfNeeded];
    [super tearDown];
}

- (NSMutableArray *)instantiateLayerClientsWithCount:(NSUInteger)count
{
    NSMutableArray *clients = [NSMutableArray new];
    for (int i = 0; i < count; i++) {
        LYRClient *layerClient = [LYRClient clientWithAppID:LSLayerAppID(self.testInterface.testEnvironment)];
        LSTestUser *testUser = [LSTestUser testUserWithNumber:i];
        layerClient = [self.testInterface authenticateLayerClient:layerClient withTestUser:testUser];
        NSLog(@"Layer Client %@", layerClient);
        [clients addObject:layerClient];
    }
    return clients;
}

- (void)testToAttemptMassivePushNotificationFrenzy
{
    LYRClient *client = self.layerClients[0];
    [self clearPreviousConversationsForLayerClient:client];
    [self createNewConversationForClient:client withDeviceIDs:@[@"b79671cf-a132-45f9-9249-ac397d6e6c76"]];
    [self sendMessagesWithMaxDelay:5 maxCount:10 itterations:500];
}

- (void)clearPreviousConversationsForLayerClient:(LYRClient *)layerClient
{
    LYRQuery *query = [LYRQuery queryWithClass:[LYRConversation class]];
    NSError *error;
    NSOrderedSet *conversations = [layerClient executeQuery:query error:&error];
    if (error) {
        NSLog(@"Failed to to fetch conversations with error: %@", error);
    } else {
        NSLog(@"Fetched conversation");
    }
    for (LYRConversation *conversation in conversations) {
        [conversation delete:LYRDeletionModeAllParticipants error:&error];
        if (error) {
            NSLog(@"Failed to to delete conversations with error: %@", error);
        } else {
            NSLog(@"Deleted conversation");
        }
    }
}

- (void)createNewConversationForClient:(LYRClient *)layerClient withDeviceIDs:(NSArray *)deviceIDs
{
    // Add devices user identifiers
    NSMutableArray * participants = [[self.layerClients valueForKeyPath:@"authenticatedUserID"] mutableCopy];
    [participants addObjectsFromArray:deviceIDs];
    
    NSError *error;
    LYRConversation *conversation = [layerClient newConversationWithParticipants:[NSSet setWithArray:participants] options:nil error:&error];
    if (error) {
        NSLog(@"Failed to create conversation with error %@", error);
    }
    
    LYRMessagePart *part = [LYRMessagePart messagePartWithText:[NSString stringWithFormat:@"Test Message %lu", (unsigned long)self.messageCount]];
    LYRMessage *message = [layerClient newMessageWithParts:@[part] options:nil error:&error];
    [conversation sendMessage:message error:&error];
    if (error) {
        NSLog(@"Failed to send message with error: %@", error);
    } else {
        NSLog(@"Message Sent");
    }
}

- (void)sendMessagesWithMaxDelay:(NSUInteger)maxDelay maxCount:(NSUInteger)maxCount itterations:(NSUInteger)itterations
{
    for (int i = 0; i < itterations; i++) {
        int timeInterval = arc4random_uniform((int)maxDelay);
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:timeInterval]];
        dispatch_async(self.messageQueue, ^{
            int clientIndex = arc4random_uniform((int)self.layerClients.count);
            int numberOfMessages = arc4random_uniform((int)maxCount);
            LYRClient *layerClient = self.layerClients[clientIndex];
            [self sendMessagesForLayerClient:layerClient count:numberOfMessages];
        });
    }
}

- (void)sendMessagesForLayerClient:(LYRClient *)layerClient count:(NSUInteger)count
{
    // Fetch the conversation
    LYRQuery *query = [LYRQuery queryWithClass:[LYRConversation class]];
    NSError *error;
    NSOrderedSet *conversations = [layerClient executeQuery:query error:&error];
    if (error) {
        NSLog(@"Failed to to fetch conversations with error: %@", error);
    } else {
        NSLog(@"Fetched conversation");
    }
    
    // Mark all messages as read
    LYRConversation *conversation = conversations[0];
    [conversation markAllMessagesAsRead:&error];
    if (error) {
        NSLog(@"Failed to mark all messages as read with error: %@", error);
    } else {
        NSLog(@"Successfully marked all messages as read");
    }
    
    // Send the messages
    for (int i = 0; i < count;  i++) {
        self.messageCount += 1;
        NSLog(@"Sending Message number %lu from %@", (unsigned long)self.messageCount, layerClient.authenticatedUserID);
        LYRMessagePart *part = [LYRMessagePart messagePartWithText:[NSString stringWithFormat:@"Test Message %lu", (unsigned long)self.messageCount]];
        LYRMessage *message = [layerClient newMessageWithParts:@[part] options:nil error:&error];
        [conversation sendMessage:message error:&error];
        if (error) {
            NSLog(@"Failed to send message with error: %@", error);
        } else {
            NSLog(@"Message Sent");
        }
    }
}

@end
