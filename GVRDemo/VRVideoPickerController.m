//
//  VRVideoPickerController.m
//  GVRDemo
//
//  Created by mac-vincent on 2017/5/12.
//  Copyright © 2017年 Vincent. All rights reserved.
//

#import "VRVideoPickerController.h"
#import "VRPlayerViewController.h"
@interface VRVideoPickerController ()
@property (nonatomic, strong) NSArray * videoURLs;
@end

@implementation VRVideoPickerController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSArray * vrVideo = [[NSBundle mainBundle] pathsForResourcesOfType:@"mp4" inDirectory:@""];
    self.videoURLs = vrVideo;
    self.tableView.rowHeight = 80;
    [self.tableView reloadData];
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.tableView.frame = CGRectMake(0, 60, [UIScreen mainScreen].bounds.size.width,  [UIScreen mainScreen].bounds.size.height - 60);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.videoURLs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"VRVideo"];
    if(!cell) {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"VRVideo"];
        if(self.videoURLs) {
            NSString * path = [self.videoURLs objectAtIndex:indexPath.row];
            NSString * fileWithExtension = [[path componentsSeparatedByString:@"/"] lastObject];
            NSString * fileName =[[fileWithExtension componentsSeparatedByString:@"."] firstObject];
            cell.textLabel.text = fileName;
        }
        
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString * path = [self.videoURLs objectAtIndex:indexPath.row];
    NSString * fileWithExtension = [[path componentsSeparatedByString:@"/"] lastObject];
    NSString * fileName =[[fileWithExtension componentsSeparatedByString:@"."] firstObject];
    VRPlayerViewController * player = [VRPlayerViewController new];
    player.playFileUrl = fileName;
    [self.navigationController pushViewController:player animated:YES];
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
