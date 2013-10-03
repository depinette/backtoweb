//
//  CoreDataHandler.m
//  SamplesHandler
//
//  Created by depsys on 24/07/13.
//  Copyright (c) 2013 depsys. All rights reserved.
//

#import <Backtoweb/Backtoweb.h>
#import "CoreDataHandler.h"

static NSPersistentStoreCoordinator* persistentStoreCoordinator = nil;
static NSExpressionDescription *maxIDExpressionDescription = nil;
static NSManagedObjectModel *mom = nil;

@implementation CoreDataHandler

+(void)initializeHandlers:(FCHandlerManager*)handlerManager
{
    //initialize global data
    [self initializeCoreData];
    
    //handles:
    //samples/messages(?method=&message=), return {status:ok, id:<id>, date:<date>, message:<message>}
    //samples/messages/<id>(?method=&message=), return {status:ok, id:<id>, date:<date>, message:<message>}
    [handlerManager
     addHandler:^BOOL(FCURLRequest *request, FCResponseStream *responseStream, NSMutableDictionary* context)
     {
         int32_t theId = 0;
         NSMutableDictionary* result = [NSMutableDictionary dictionaryWithCapacity:2];
         NSDictionary* objectValues = nil;
         NSArray* objects = nil;
         NSArray* pathComponents = [request.URL pathComponents];
         if (pathComponents.count > 3)
         {
             theId = [[pathComponents objectAtIndex:3] intValue];
         }

         //We could use request.HTTPMethod for REST
         NSString* method  = [request valueForFormField:kURLKeyMethod];
         NSString* message = [request valueForFormField:kURLKeyMessage];
         
         if (method == nil || [method compare:kURLKeyMethodGet options:NSCaseInsensitiveSearch] == NSOrderedSame)
         {
             if (theId != 0) //one message
                 objectValues = [self fetchMessageWithId:theId andSetMessage:nil];
             else //all messages
             {
                 NSString* from =[request valueForFormField:kURLKeyFrom];
                 NSString* nb =[request valueForFormField:kURLKeyNumber];
                 objects = [self fetchMessagesFrom:from?[from integerValue]:0 number:nb?[nb integerValue]:0];
             }
         }
         else if ([method compare:kURLKeyMethodSet options:NSCaseInsensitiveSearch] == NSOrderedSame)
         {
             if (theId != 0)
                 objectValues = [self fetchMessageWithId:theId andSetMessage:message];
         }
         else if ([method compare:kURLKeyMethodNew options:NSCaseInsensitiveSearch] == NSOrderedSame)
         {
             objectValues = [self createMessage:message];
         }
         
         //encapsulate for JSON serialization
         if (objectValues != nil)
         {
             [result setValue:@"ok" forKey:kJSONStatus];
             [result setValue:objectValues forKey:kJSONKeyItem];
         }
         else if (objects != nil)
         {
             [result setValue:@"ok" forKey:kJSONStatus];
             [result setValue:objects forKey:kJSONKeyItems];
         }
         else
         {
             [result setValue:@"error" forKey:kJSONStatus];
         }

         NSError* error = nil;
         if (0 == [NSJSONSerialization writeJSONObject:result toStream:responseStream options:NSJSONWritingPrettyPrinted error:&error])
         {
             DDLogError(@"NSJSONSerialization Error: %@", error);
         }

         return NO; //do not try to find another handler
     }
     forRegexPath:@"^/samples/messages(?:/[^/]*)?" pathType:FCPathTypeURLPath priority:FCHandlerPriorityNormal];
}

+ (NSDictionary*)createMessage:(NSString*)message
{
    NSManagedObject* item = nil;
    NSError *error = nil;
    
    NSManagedObjectContext* managedObjectContext = [self contextForCurrentThread];
    if (managedObjectContext)
    {
        //request the max of ID
        NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] initWithEntityName:kItemKeyEntity];
        [fetchRequest setResultType:NSDictionaryResultType];
        [fetchRequest setPropertiesToFetch:[NSArray arrayWithObject:maxIDExpressionDescription]];

        NSArray *results = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
        if (results != nil)
        {
            NSNumber* max = [[results objectAtIndex:0] valueForKey:kItemKeyMaxId];
            item = [NSEntityDescription insertNewObjectForEntityForName:kItemKeyEntity inManagedObjectContext:managedObjectContext];
            [item setValue:[[NSNumber alloc] initWithUnsignedLongLong:(max?[max unsignedLongLongValue]+1:1)] forKey:kItemKeyId];
            [item setValue:[NSDate date] forKey:kItemKeyDate];
            [item setValue:message forKey:kItemKeyMessage];
            if ([managedObjectContext save:&error] == NO)
                DDLogError(@"Error %@ while saving database", error);
        }
        else
        {
            DDLogError(@"unknown error while fetching maxID");
        }
    }

    if (item)
        return [self itemToDictionary:item];
    return nil;
}

+ (NSDictionary*)fetchMessageWithId:(int32_t)theId andSetMessage:(NSString*)message
{
    NSManagedObject* item = nil;
    NSError *error = nil;

    NSManagedObjectContext* managedObjectContext = [self contextForCurrentThread];
    if (managedObjectContext)
    {
        //get Item from Id
        NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] initWithEntityName:kItemKeyEntity];
        fetchRequest.predicate = [NSPredicate predicateWithFormat: @"id == %d", /*kItemKeyId,*/ theId];
        NSArray *results = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
        if (results != nil && results.count > 0)
        {
            item = [results objectAtIndex:0];
            //update Item if necessary
            if (message)
            {
                [item setValue:[NSDate date] forKey:kItemKeyDate];
                [item setValue:message forKey:kItemKeyMessage];
                //sleep(2);//temp concurrency test
            
                if ([managedObjectContext save:&error] == NO)
                    DDLogError(@"Error %@ while saving database", error);
            }
        }
        else
        {
            DDLogError(@"unknown error while fetching item with id=%d", theId);
        }
    }

    if (item)
        return [self itemToDictionary:item];
    return nil;

}

#define MAX_NUMBER_MSG 100
+ (NSArray*)fetchMessagesFrom:(NSInteger)from number:(NSInteger)number
{
    NSMutableArray *objects = nil;
    NSError *error = nil;

    if (number <= 0 || number > MAX_NUMBER_MSG) number = MAX_NUMBER_MSG;
    if (from < 0) from = 0;

    NSManagedObjectContext* managedObjectContext = [self contextForCurrentThread];
    if (managedObjectContext)
    {
        //Fetch all item (from to)
        NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] initWithEntityName:kItemKeyEntity];
        [fetchRequest setFetchLimit:number];
        [fetchRequest setFetchOffset:from];

        NSArray *results = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
        if (results != nil)
        {
            //convert item to dictionary
            objects = [[NSMutableArray alloc] initWithCapacity:results.count];
            for (int i = 0; i < results.count; i++)
            {
                NSManagedObject* item = [results objectAtIndex:i];
                [objects addObject:[self itemToDictionary:item]];
            }
        }
        else
        {
            DDLogError(@"unknown error while fetching items from=%ld limit=%ld", from, number);
        }
    }
    return objects;
}

+(void)initializeCoreData
{
    //create the model
    [self initModel];
    
    [self initStoreCoordinator];


    //prepare some special properties for future fetching (@maxId)
    NSExpression *keyPathExpression = [NSExpression expressionForKeyPath:kItemKeyId];
    NSExpression *maxIDExpression = [NSExpression expressionForFunction:@"max:" arguments:[NSArray arrayWithObject:keyPathExpression]];
    maxIDExpressionDescription = [[NSExpressionDescription alloc] init];
    [maxIDExpressionDescription setName:kItemKeyMaxId];
    [maxIDExpressionDescription setExpression:maxIDExpression];
    [maxIDExpressionDescription setExpressionResultType:NSInteger32AttributeType];
}

+ (void)initModel
{
    NSEntityDescription *runEntity = [[NSEntityDescription alloc] init];
    [runEntity setName:kItemKeyEntity];
    [runEntity setManagedObjectClassName:kItemKeyEntity];
    
    NSAttributeDescription *dateAttribute = [[NSAttributeDescription alloc] init];
    [dateAttribute setName:kItemKeyDate];
    [dateAttribute setAttributeType:NSDateAttributeType];
    [dateAttribute setOptional:NO];
    
    NSAttributeDescription *messageAttribute = [[NSAttributeDescription alloc] init];
    [messageAttribute setName:kItemKeyMessage];
    [messageAttribute setAttributeType:NSStringAttributeType];
    [messageAttribute setOptional:NO];
    
    NSAttributeDescription *idAttribute = [[NSAttributeDescription alloc] init];
    [idAttribute setName:kItemKeyId];
    [idAttribute setAttributeType:NSInteger32AttributeType];
    [idAttribute setOptional:NO];
    
    [runEntity setProperties:@[idAttribute, dateAttribute, messageAttribute]];
    
    mom = [[NSManagedObjectModel alloc] init];
    [mom setEntities:@[runEntity]];
}

+ (void)initStoreCoordinator
{
    //Compute store URL
    NSString* directory = [NSString pathWithComponents:@[[[FCServerContext sharedInstance] dataDirectory], @"sample"]];
    NSError *error = nil;
    if ([[NSFileManager new] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error] == NO)
    {
        DDLogError(@"Error %@ while creating directory %@", error, directory);
    }
    NSURL *storeURL = [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:@"sample.sqlite"]];
    
    //Create persistent store coordinator
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
							 [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
							 [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption,
							 nil];
    
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
    if (persistentStoreCoordinator)
    {
        if (![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error])
        {
            DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
        }
    }
}


static NSString * const kThreadContextKey = @"sample_context_for_thread";
+(NSManagedObjectContext*)contextForCurrentThread
{
    NSMutableDictionary *threadDict = [[NSThread currentThread] threadDictionary];
    NSManagedObjectContext *context = [threadDict objectForKey:kThreadContextKey];
    if (context == nil)
    {
        context = [[NSManagedObjectContext alloc ]initWithConcurrencyType:NSConfinementConcurrencyType];
        [context setPersistentStoreCoordinator: persistentStoreCoordinator];
        [context setUndoManager:nil];
        [context setMergePolicy:NSOverwriteMergePolicy];

        [threadDict setObject:context forKey:kThreadContextKey];
    }
    return context;
}

+(NSDictionary*)itemToDictionary:(NSManagedObject*)item
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [item valueForKey:kItemKeyId] , kJSONKeyId,
            [item valueForKey:kItemKeyMessage], kJSONKeyMessage,
            //JSON serialisation does not support NSDate
            [[item valueForKey:kItemKeyDate] descriptionWithCalendarFormat:nil timeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"] locale:nil], kJSONDate,//“%Y-%m-%d %H:%M:%S %z”
            nil];
}
@end
