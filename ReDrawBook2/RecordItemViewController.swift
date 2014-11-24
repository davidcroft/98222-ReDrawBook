//
//  RecordItemViewController.swift
//  ReDrawBook2
//
//  Created by Ding Xu on 10/14/14.
//  Copyright (c) 2014 Ding Xu. All rights reserved.
//

import UIKit

class RecordItemViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet var RecordItemPageImg: UIImageView!
    @IBOutlet var RecordItemPageTitle: UILabel!
    @IBOutlet var RecordItemPageDesp: UILabel!
    @IBOutlet var RecordItemPageTableView: UITableView!
    
    var bookInfo: BookInfo!
    var pages:[PageInfo] = []
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.RecordItemPageTitle.text = self.bookInfo.title
        self.RecordItemPageDesp.text = self.bookInfo.description
        self.RecordItemPageImg.image = self.bookInfo.coverImage?
        //self.RecordItemPageImg.image = UIImage(data: NSData(contentsOfURL: NSURL(string: self.albumInfo!.largeImageURL)!)!)
        
        // get all the pages info
        var query = PFQuery(className: "page")
        query.whereKey("bookName", equalTo:self.bookInfo.title)
        query.addAscendingOrder("pageIndex")
        query.findObjectsInBackgroundWithBlock {
            (objects:[AnyObject]!, error: NSError!) ->Void in
            //dispatch_async(dispatch_get_main_queue(), {
            if (error == nil) {
                for object in objects {
                    var bookName: String = object.objectForKey("bookName") as String
                    if (bookName == self.bookInfo.title) {
                        var pageIndex: Int = object.objectForKey("pageIndex") as Int
                        var pageTitle: String = object.objectForKey("pageTitle") as String
                        var pageImagePF: PFFile? = object.objectForKey("pageImage") as PFFile?
                        var pageImageData: NSData? = pageImagePF?.getData() as NSData?
                        var pageCoverImage: UIImage!
                        if (pageImageData != nil ) {
                            pageCoverImage = UIImage(data: pageImageData!)!
                        } else {
                            pageCoverImage = UIImage(named:"bookThumbDefault.jpg")!
                        }
                        var newPageItem:PageInfo = PageInfo(title: pageTitle, index: pageIndex, pageImage: pageCoverImage)
                        
                        self.pages.append(newPageItem)
                    }
                    self.RecordItemPageTableView.reloadData()
                }
            }
        }
        self.RecordItemPageTableView.rowHeight = 50
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: UITableViewDataSource
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.pages.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("AlbumItem") as? RecordAlbumTableViewCell ?? RecordAlbumTableViewCell()
        
        let page = pages[indexPath.row]
        cell.titleLabel.text = page.pageTitle
        cell.pageIndex.text = String(page.pageIndex) + "/" + String(bookInfo.pagesNum)
        cell.pageCoverImage.image = page.pageImage
        
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    }
    
    // MARK: APIControllerProtocol
    func didReceiveAPIResults(results: NSDictionary) {
        //var resultsArr: NSArray = results["results"] as NSArray
        //dispatch_async(dispatch_get_main_queue(), {
        //    self.tracks = AlbumTrack.tracksWithJSON(resultsArr)
        //    self.RecordItemPageTableView.reloadData()
        //    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        //})
    }
    

    /////////////// swipe left to appear buttons /////////////
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        /*if editingStyle == .Delete {
            println("COMMIT-DELETE")
        } else if editingStyle == .Insert {
            println("COMMIT-INSERT")
        }*/
        return
    }
    
    func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [AnyObject]? {
        
        var moreRowAction = UITableViewRowAction(style: UITableViewRowActionStyle.Default, title: "More", handler:{action, indexpath in
            println("MORE•ACTION");
        });
        moreRowAction.backgroundColor = UIColor(red: 0.298, green: 0.851, blue: 0.3922, alpha: 1.0);
        
        /*var deleteAllRowAction = UITableViewRowAction(style: UITableViewRowActionStyle.Default, title: "Delete All", handler:{action, indexpath in
            println("DELETE-ALL•ACTION");
        });*/
        
        var deleteRowAction = UITableViewRowAction(style: UITableViewRowActionStyle.Default, title: "Delete", handler:{action, indexpath in
            println("DELETE•ACTION");
        });
        
        //return [deleteRowAction, deleteAllRowAction, moreRowAction];
        return [deleteRowAction, moreRowAction];
    }
    
    ///////////////////


    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue!, sender: AnyObject!) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
