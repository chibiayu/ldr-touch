#import "PinListViewController.h"
#import "PinListCell.h"
#import "LDRTouchAppDelegate.h";
#import "SiteViewController.h"
#import "NSString+XMLExtensions.h"
#import "JSON.h";
#import "Debug.h"

@implementation PinListViewController

@synthesize pinListView;
@synthesize pinList;

- (void)dealloc {
	LOG_CURRENT_METHOD;
	[pinList release];
	[conn release];
	[pinListView release];
    [super dealloc];
}

- (void)reset {
	[conn setDelegate:nil];
	[conn release];
	conn = nil;
}

- (IBAction)hidePinList {
	[self dismissModalViewControllerAnimated:YES];
}

- (void)getPinList {
	LoginManager *loginManager = [LDRTouchAppDelegate sharedLoginManager];
	if (!loginManager.api_key) {
		[loginManager setDelegate:self];
		[loginManager login];
		return;
	}
	
	[conn cancel];
	[self reset];
	
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
	
	LDRTouchAppDelegate *sharedLDRTouchApp = [LDRTouchAppDelegate sharedLDRTouchApp];
	UserSettings *userSettings = sharedLDRTouchApp.userSettings;
	
	conn = [[HttpClient alloc] initWithDelegate:self];
	[conn post:[NSString stringWithFormat:@"%@%@%@", @"http://", userSettings.serviceURI, @"/api/pin/all"]
	parameters:[NSDictionary dictionaryWithObjectsAndKeys:
				loginManager.api_key, @"ApiKey", nil]];
}

- (BOOL)deletePin:(NSString *)link {
	LDRTouchAppDelegate *sharedLDRTouchApp = [LDRTouchAppDelegate sharedLDRTouchApp];
	UserSettings *userSettings = sharedLDRTouchApp.userSettings;
	
	LoginManager *loginManager = [LDRTouchAppDelegate sharedLoginManager];
	NSURL *apiURI = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", @"http://", userSettings.serviceURI, @"/api/pin/remove"]];
	NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:apiURI
													   cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:180.0];
	
	[req setHTTPMethod:@"POST"];
    [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
	NSString *body = [NSString stringWithFormat:@"link=%@&ApiKey=%@", link, loginManager.api_key];
    [req setValue:[NSString stringWithFormat:@"%d", body.length] forHTTPHeaderField:@"Content-Length"];
	[req setHTTPBody:[[body stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] dataUsingEncoding:NSUTF8StringEncoding]];
	[req setHTTPShouldHandleCookies:YES];
	
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
	
	NSHTTPURLResponse *res;
	[NSURLConnection sendSynchronousRequest:req returningResponse:&res error:nil];
	
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	
	if ([res statusCode] == 200) {
		LOG(@"remove pin: <%@>, %d", link, [res statusCode]);
		return YES;
	} else {
		return NO;
	}
}

- (void)httpClientSucceeded:(HttpClient*)sender response:(NSHTTPURLResponse*)response data:(NSData*)data {
	NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	
	NSMutableArray *listOfPin = [s JSONValue];
	[s release];
	if (!listOfPin) {
		return;
	}
	
	self.pinList = listOfPin;
	[self.pinListView reloadData];
	
	LDRTouchAppDelegate *sharedLDRTouchApp = [LDRTouchAppDelegate sharedLDRTouchApp];
	UserSettings *userSettings = sharedLDRTouchApp.userSettings;
	userSettings.pinList = self.pinList;
	
	[self reset];
	
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

- (void)httpClientFailed:(HttpClient*)sender error:(NSError*)error {
	[self reset];
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

- (void)loginManagerSucceeded:(LoginManager *)sender apiKey:(NSString *)apiKey {
	[sender setDelegate:nil];
	[self getPinList];
}

- (void)loginManagerFailed:(LoginManager *)sender error:(NSError *)error {
	[sender setDelegate:nil];
}

#pragma mark <UITableViewDataSource> Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [pinList count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *CellIdentifier = @"PinListCell";
	PinListCell *cell = (PinListCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
		cell = [[[PinListCell alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 44.0f) reuseIdentifier:CellIdentifier] autorelease];
    }
	[cell.titleLabel setText:[NSString decodeXMLCharactersIn:[[pinList objectAtIndex:indexPath.row] objectForKey:@"title"]]];
 	[cell.linkLabel setText:[NSString decodeXMLCharactersIn:[[pinList objectAtIndex:indexPath.row] objectForKey:@"link"]]];
    return cell;
}

#pragma mark <UITableViewDelegate> Methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[self dismissModalViewControllerAnimated:YES];
	SiteViewController *controller = [[LDRTouchAppDelegate sharedLDRTouchApp] sharedSiteViewController];
	NSDictionary *pin = [pinList objectAtIndex:indexPath.row];
	controller.pageURL = [NSString decodeXMLCharactersIn:[pin objectForKey:@"link"]];
	controller.title = [NSString decodeXMLCharactersIn:[pin objectForKey:@"title"]];
	[(UINavigationController *)[self parentViewController] pushViewController:controller animated:YES];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		NSString *link = [NSString decodeXMLCharactersIn:[[pinList objectAtIndex:indexPath.row] objectForKey:@"link"]];
		if ([self deletePin:link]) {
			[pinList removeObjectAtIndex:indexPath.row];
			[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
		}
    }
}

#pragma mark <UIViewController> Methods

- (void)viewDidLoad {
    [super viewDidLoad];
	[self getPinList];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
	LOG_CURRENT_METHOD;
}

@end

