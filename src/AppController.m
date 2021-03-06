/*
 
 The MIT License
 
 Copyright (c) 2010 Mike Chambers (mikechambers@gmail.com)
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE. 
 
 */

#import "AppController.h"
#import "Broadcast.h"
#import "NSString+TSVCategory.h"
#import "NSArrayFormatter.h"
#import "NSTextField+TimeCategory.h"
#import "CalendarSheetController.h"


#define ALL_MENU_TAG 20
#define START_MENU_TAG 21
#define END_MENU_TAG 22
#define COUNTRY_MENU_TAG 23
#define STATION_MENU_TAG 24
#define NOTES_MENU_TAG 25
#define FREQUENCY_MENU_TAG 26
#define NOW_MENU_TAG 28

#define CLEAR_CACHE_MENU 58
#define MAIN_WINDOW_MENU_TAG 150

@implementation AppController
 
@synthesize broadcasts;

-(id)init
{
	if(![super init])
	{
		return nil;
	}
	
	broadcasts = [[NSMutableArray alloc] init];
	calendarSheet = [[CalendarSheetController alloc] init];
	
	allSearch = TRUE;
	startSearch = FALSE;
	endSearch = FALSE;
	countrySearch = FALSE;
	stationSearch = FALSE;
	notesSearch = FALSE;
	frequencySearch = FALSE;
	nowSearch = FALSE;
	
	return self;
}

-(void)dealloc
{
	[broadcasts release];
	[filteredBroadcasts release];
	[calendarSheet release];
	[super dealloc];
}


-(void)awakeFromNib
{
	[countLabel setStringValue:@""];
	[timerLabel startTimer];
	
	[mainWindow setReleasedWhenClosed:FALSE];
	
	NSArrayFormatter *arrayFormatter = [[NSArrayFormatter alloc] init];
	
	NSTableColumn *fCol = [broadcastTable tableColumnWithIdentifier:@"frequencies"];
	NSCell *fCell = [fCol dataCell];
	[fCell setFormatter:arrayFormatter];
	
	//this is to work around some Interface Builder bugs.
	//basically, it wont remove some of the items, so we have to do it manually
	[topToolBar removeItemAtIndex:4];
	[topToolBar removeItemAtIndex:0];
	
	//[mainWindow setAutorecalculatesContentBorderThickness:YES forEdge:NSMinYEdge];
	//[mainWindow setContentBorderThickness: 32.0 forEdge: NSMinYEdge];
	
	[self loadBroadcastData];
}

-(void)updateBroadcasts:(NSMutableArray *)b
{
	[broadcasts removeAllObjects];
	[broadcasts addObjectsFromArray:b];
	
	filteredBroadcasts = [broadcasts mutableCopy];
}

-(void)refreshData
{
	[broadcastTable reloadData];
	[countLabel setStringValue:[NSString stringWithFormat:@"%i of %i broadcasts", [filteredBroadcasts count], [broadcasts count]]];
}

-(void)filterBroadcastsForNow
{
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
	[dateFormatter setDateFormat:@"HHmm"];
	
	NSDate *date = [NSDate date];
	
	NSString *current = [dateFormatter stringFromDate:date];
	
	[dateFormatter release];	
	
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%@ BETWEEN {startTime, endTime}", current];
	
	[filteredBroadcasts filterUsingPredicate:predicate];
}

-(void)importFromFilePath:(NSString *)filePath
{	
	NSError *error = nil;
	NSStringEncoding enc;
	
	
	
	NSString *data = [NSString stringWithContentsOfFile:filePath
										   usedEncoding:&enc 
												  error:&error];

	if(!data)
	{
		error = nil;
		data = [NSString stringWithContentsOfFile:filePath
										   encoding:NSMacOSRomanStringEncoding
												  error:&error];	
	}
	
	if(error)
	{
		NSLog(@"Error : %@", error);
	}
	
	if(data == nil)
	{
		NSAlert *alert = [[NSAlert alloc] init];
		[alert addButtonWithTitle:@"OK"];
		[alert setMessageText:@"Error importing data."];
		[alert setInformativeText:@"Please ensure the file is in the correct format."];
		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert runModal];
		[alert release];		
		return;
	}
	
	NSMutableArray *b = [[data arrayOfBroadcastsFromTSV] retain];

	[self updateBroadcasts:b];

	[self saveBroadcastData];
	[self refreshData];
}

-(NSString *) appName
{
	return [[NSProcessInfo processInfo] processName];
}

/***************  data persitence apis **************/

-(void)saveBroadcastData
{
	NSString *path = [self pathForDataFile];
	
	NSMutableDictionary *rootObject = [NSMutableDictionary dictionary];
    
	[rootObject setValue: [self broadcasts] forKey:@"broadcasts"];
	[NSKeyedArchiver archiveRootObject: rootObject toFile: path];
}

-(void)loadBroadcastData
{
	NSString *path = [self pathForDataFile];
	
	if(![self fileExistsAtPath:path])
	{
		return;
	}
	
	NSDictionary * rootObject = [NSKeyedUnarchiver unarchiveObjectWithFile:path]; 
	
	NSMutableArray *b = [rootObject valueForKey:@"broadcasts"];
	
	if([b count] == 0)
	{
		return;
	}
	
	[self updateBroadcasts:b];
	
	[self refreshData];
}

- (NSString *) pathForDataFile
{
	NSString *appName = [self appName];
    
	NSString *folder = [NSString stringWithFormat:@"~/Library/Application Support/%@/", appName];
	folder = [folder stringByExpandingTildeInPath];
	
	if ([self fileExistsAtPath:folder] == NO)
	{
		NSFileManager *fMan = [NSFileManager defaultManager];
		[fMan createDirectoryAtPath: folder attributes: nil];
	}
    
	NSString *fileName = [NSString stringWithFormat:@"%@.broadcasts", appName];
	
	return [folder stringByAppendingPathComponent: fileName];    
}

-(Boolean)fileExistsAtPath:(NSString *)path
{
	NSFileManager *fMan = [NSFileManager defaultManager];
	
	return [fMan fileExistsAtPath:path];
}


/*************** app menu actions******************/

//MAIN_WINDOW_MENU_TAG

-(IBAction)handleNewMainWindowMenu:(NSMenuItem *)sender
{
	[mainWindow makeKeyAndOrderFront:self];
}

-(IBAction)handleFileImportMenu:(NSMenuItem *)sender
{
    int result;
	NSArray *fileTypes = [NSArray arrayWithObjects: @"txt", @"text",
						  NSFileTypeForHFSTypeCode( 'TEXT' ), nil];
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
	
    [oPanel setAllowsMultipleSelection:NO];
	[oPanel setCanChooseDirectories:NO];
    result = [oPanel runModalForDirectory:NSHomeDirectory()
									 file:nil types:fileTypes];	
	
	NSString *importPath;
	if(result == NSOKButton)
	{
		//todo: should i check that it contains anything?
		importPath = [[oPanel filenames] objectAtIndex:0];
	}
	else
	{
		return;
	}
	
	[self importFromFilePath:importPath];
}

-(IBAction)handleClearCacheMenu:(NSMenuItem *)sender
{
	NSString *path = [self pathForDataFile];
	
	NSFileManager *fMan = [NSFileManager defaultManager];
	
	Boolean suc = [fMan removeItemAtPath:path error:NULL];

	[self updateBroadcasts:[NSMutableArray arrayWithCapacity:0]];
	[self refreshData];
	
	if(!suc)
	{
		NSLog(@"Could not delete cache.");
	}
}
	
- (BOOL)validateMenuItem:(NSMenuItem *)item
{
	if([item tag] == CLEAR_CACHE_MENU)
	{
		NSString *path = [self pathForDataFile];
		return [self fileExistsAtPath:path];
	}
	else if([item tag] == MAIN_WINDOW_MENU_TAG)
	{
		return ![mainWindow isVisible];
	}
	
	return TRUE;
}

/************** calendar actions ******************/

-(IBAction)handleAddCalendar:(id)sender
{
	NSInteger row = [broadcastTable selectedRow];
	
	if(row == -1)
	{
		//we should never get here
		NSAssert(FALSE, @"handleAddCalender called when no Broadcast was selected.");
		return;
	}
	
	
	Broadcast *b = [filteredBroadcasts objectAtIndex:row];
	[calendarSheet showSheet:mainWindow forBroadcast:b];	
}

/**************** search actions ******************/

-(IBAction)handleNowSearch:(NSMenuItem *)nowMenuItem
{	
	NSInteger state;
	
	if([nowMenuItem state] == NSOffState)
	{
		state = NSOnState;
		nowSearch = TRUE;
	}
	else
	{
		state = NSOffState;
		nowSearch = FALSE;
	}
	
	[nowMenuItem setState:state];
	
	[self filterBroadcastsForNow];
	
	//todo: this doesnt always need to be called
	[self refreshData];
}

-(IBAction)handleSearchMenuItems:(NSMenuItem *)menuItem
{
	if([menuItem state] == NSOffState)
	{
		[menuItem setState:NSOnState];
		
		NSMenu *menu = [menuItem menu];
		NSArray *menuItems = [menu itemArray];
	
		for(NSMenuItem *item in menuItems)
		{
			if(item != menuItem)
			{
				if([item tag] == NOW_MENU_TAG)
				{
					continue;
				}
				
				[item setState:NSOffState];
			}
		}
	}
	
	allSearch = FALSE;
	startSearch = FALSE;
	endSearch = FALSE;
	countrySearch = FALSE;
	stationSearch = FALSE;
	notesSearch = FALSE;
	frequencySearch = FALSE;	
	
	//NSString *title = [menuItem title];
	NSInteger tag = [menuItem tag];
	
	if(tag == ALL_MENU_TAG)
	{
		allSearch = TRUE;
	}
	else if(tag == START_MENU_TAG)
	{
		startSearch = TRUE;
	}
	else if(tag == END_MENU_TAG)
	{
		endSearch = TRUE;
	}
	else if(tag == COUNTRY_MENU_TAG)
	{
		countrySearch = TRUE;
	}
	else if(tag == STATION_MENU_TAG)
	{
		stationSearch = TRUE;
	}
	else if(tag == NOTES_MENU_TAG)
	{
		notesSearch = TRUE;
	}
	else if(tag == FREQUENCY_MENU_TAG)
	{
		frequencySearch = TRUE;
	}
}

-(IBAction)handleSearch:(NSSearchField *)searchField
{
	NSString *searchString = [searchField stringValue];
	
	//todo : the array somestimes get copied when it doesnt need to be
	//specifically, if the searchString is empty and Current menu item
	//is not selected.
	[filteredBroadcasts release];
	filteredBroadcasts = [broadcasts mutableCopy];
	
	if(nowSearch)
	{
		[self filterBroadcastsForNow];
	}	
	
	if([searchString length] == 0)
	{
		[self refreshData];
		return;
	}

	NSPredicate *startPredicate = [NSPredicate predicateWithFormat:@"startTime contains[c] %@", searchString];
	NSPredicate *endPredicate = [NSPredicate predicateWithFormat:@"endTime contains[c] %@", searchString];
	NSPredicate *countryPredicate = [NSPredicate predicateWithFormat:@"country contains[c] %@", searchString];
	NSPredicate *stationPredicate = [NSPredicate predicateWithFormat:@"station contains[c] %@", searchString];
	NSPredicate *notesPredicate = [NSPredicate predicateWithFormat:@"notes contains[c] %@", searchString];
	NSPredicate *frequencyPredicate = [NSPredicate predicateWithFormat:@"ANY frequencies contains[c] %@", searchString];
	
	NSPredicate *predicate;
	
	if(startSearch)
	{
		predicate = startPredicate;
	}
	else if(endSearch)
	{
		predicate = endPredicate;
	}
	else if(countrySearch)
	{
		predicate = countryPredicate;
	}
	else if(stationSearch)
	{
		predicate = stationPredicate;
	}
	else if(notesSearch)
	{
		predicate = notesPredicate;
	}
	else if(frequencySearch)
	{
		predicate = frequencyPredicate;
	}
	else
	{
		predicate = [NSCompoundPredicate
					 orPredicateWithSubpredicates:[NSArray arrayWithObjects:
													startPredicate,
													endPredicate,
													countryPredicate,
													stationPredicate,
													notesPredicate,
													frequencyPredicate,
													nil
					 ]];
	}

	[filteredBroadcasts filterUsingPredicate:predicate];
	
	[self refreshData];
}

/******* NSTableView dataProvider methods **********/

-(id)tableView:(NSTableView *)table objectValueForTableColumn:(NSTableColumn *)column row:(int)row
{
	NSString *identifier = [column identifier];
	
	Broadcast *b = [filteredBroadcasts objectAtIndex:row];
	
	return [b valueForKey:identifier];
}

-(int)numberOfRowsInTableView:(NSTableView *)TableDirectoryRecord
{
	return [filteredBroadcasts count];
}

-(void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
	NSArray *newDescriptors = [tableView sortDescriptors];
	
	[filteredBroadcasts sortUsingDescriptors:newDescriptors];

	[self refreshData];
}

/********** NSTableView delegate methods ****************/

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	NSInteger selectedCount = [broadcastTable numberOfSelectedRows];
	Boolean enabled = (selectedCount > 0);
	
	[calendarButton setEnabled:enabled];
	[addToIcalMenuItem setEnabled:enabled];
}


@end
