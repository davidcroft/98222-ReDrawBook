//
//  RecordUITableViewController.swift
//  ReDrawBook2
//
//  Created by Ding Xu on 10/14/14.
//  Copyright (c) 2014 Ding Xu. All rights reserved.
//

import UIKit

class RecordUITableViewController: UITableViewController, UITableViewDataSource, ItunesAPIControllerProtocol {
    
    var books:[BookInfo] = []
    var itunesAPI:ItunesAPIController?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        //itunesAPI = ItunesAPIController(delegate: self)
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        //itunesAPI!.searchItunesFor("Jason Mraz")
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), { () -> Void in
            var query = PFQuery(className: "book")
            query.findObjectsInBackgroundWithBlock {
                (objects:[AnyObject]!, error: NSError!) ->Void in
                    if error == nil {
                        for object in objects {
                            var bookTitle: String = object.objectForKey("title") as String
                            var bookDescription: String = object.objectForKey("description") as String
                            var bookCoverImagePF: PFFile = object.objectForKey("coverImage") as PFFile
                            var bookImageData: NSData = bookCoverImagePF.getData() as NSData
                            var bookCoverImage: UIImage? = UIImage(data: bookImageData)
                            var newBookItem:BookInfo = BookInfo(title: bookTitle, description: bookDescription, coverImage: bookCoverImage, pagesNum: 5)
                            /*dispatch_async(dispatch_get_main_queue(), { () -> Void in
                                self.books.append(newBookItem)
                            })*/
                            self.books.append(newBookItem)
                        }
                        self.tableView.reloadData()
                    }
            }
        })
        
        // table view init
        tableView.rowHeight = 60

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("RecordItem") as? RecordTableViewCell ?? RecordTableViewCell()
        let album = self.books[indexPath.row]
        
        cell.RecordItemTitle?.text = album.title
        cell.RecordItemDesp?.text = album.description
        //cell.RecordItemThumb?.image = UIImage(named: "Blank52")
        cell.RecordItemThumb?.image = album.coverImage
        
        // Grab the artworkUrl60 key to get an image URL for the app's thumbnail
        //let urlString = album.thumbnailImageURL
        //let imgURL: NSURL = NSURL(string: urlString)!
        // Download an NSData representation of the image at the URL
        //let imgData: NSData = NSData(contentsOfURL: imgURL)!
        //cell.RecordItemThumb?.image = UIImage(data: imgData)
        
        return cell
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.books.count
    }
    
    func didReceiveAPIResults(results: NSDictionary) {
        var resultsArr: NSArray = results["results"] as NSArray
        dispatch_async(dispatch_get_main_queue(), {
            //self.albums = AlbumInfo.albumsWithJSON(resultsArr)
            self.tableView!.reloadData()
            // turn off network activity
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        })
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        switch segue.identifier! {
        case "AlbumToRecord":
            if var secondViewController = segue.destinationViewController as? RecordItemViewController {
                if var cell = sender as? RecordTableViewCell {
                    var albumIndex = tableView!.indexPathForSelectedRow()!.row
                    var selectedAlbum = self.books[albumIndex]
                    secondViewController.bookInfo = selectedAlbum
                }
            }
        default:
            break
        }
    }

    // MARK: - Table view data source

    /*override func numberOfSectionsInTableView(tableView: UITableView!) -> Int {
        // #warning Potentially incomplete method implementation.
        // Return the number of sections.
        return 0
    }

    override func tableView(tableView: UITableView!, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete method implementation.
        // Return the number of rows in the section.
        return 0
    }*/

    /*
    override func tableView(tableView: UITableView!, cellForRowAtIndexPath indexPath: NSIndexPath!) -> UITableViewCell! {
        let cell = tableView.dequeueReusableCellWithIdentifier("reuseIdentifier", forIndexPath: indexPath) as UITableViewCell

        // Configure the cell...

        return cell
    }
    */

    /*
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView!, canEditRowAtIndexPath indexPath: NSIndexPath!) -> Bool {
        // Return NO if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(tableView: UITableView!, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath!) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(tableView: UITableView!, moveRowAtIndexPath fromIndexPath: NSIndexPath!, toIndexPath: NSIndexPath!) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(tableView: UITableView!, canMoveRowAtIndexPath indexPath: NSIndexPath!) -> Bool {
        // Return NO if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue!, sender: AnyObject!) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    */

}
