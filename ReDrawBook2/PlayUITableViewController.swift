//
//  PlayUITableViewController.swift
//  ReDrawBook2
//
//  Created by Ding Xu on 10/13/14.
//  Copyright (c) 2014 Ding Xu. All rights reserved.
//

import UIKit
import CoreBluetooth

class PlayUITableViewController: UITableViewController, UITableViewDataSource, ItunesAPIControllerProtocol, CBCentralManagerDelegate {
    
    var albums = [AlbumInfo]()
    var itunesAPI:ItunesAPIController?
    
    //var peripheralManager: CBPeripheralManager!
    var centralManager: CBCentralManager!
    var peripehralNameList:[NSString] = []
    let serviceUUID = CBUUID(string: "6e400001-b5a3-f393-e0a9-e50e24dcca9e")
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        //peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        itunesAPI = ItunesAPIController(delegate: self)
        // turn on network activity
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        itunesAPI!.searchItunesFor("Jason Mraz")
        
        // bluetooth init
        //centralManager = CBCentralManager(delegate: self, queue: nil)
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        
        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("PlayItem") as? PlayTableViewCell ?? PlayTableViewCell()
        
        /*let album = self.albums[indexPath.row]
        cell.PlayItemTitle?.text = album.title
        cell.PlayItemDesp?.text = album.artistName
        cell.PlayItemThumb?.image = UIImage(named: "Blank52")
        
        // Grab the artworkUrl60 key to get an image URL for the app's thumbnail
        let urlString = album.thumbnailImageURL
        let imgURL: NSURL = NSURL(string: urlString)!
        // Download an NSData representation of the image at the URL
        let imgData: NSData = NSData(contentsOfURL: imgURL)!
        cell.PlayItemThumb?.image = UIImage(data: imgData)*/
        
        
        let album = self.peripehralNameList[indexPath.row]
        cell.PlayItemTitle?.text = album
        cell.PlayItemDesp?.text = "this is a description"
        
        cell.PlayItemThumb?.image = UIImage(named:"bookThumbDefault.jpg")
        // turn the image to round
        cell.PlayItemThumb.layer.cornerRadius = cell.PlayItemThumb.bounds.size.height / 2.0
        cell.PlayItemThumb.clipsToBounds = true // very important, not mask the image otherwise
        
        return cell
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        //return self.albums.count
        return self.peripehralNameList.count
    }
    
    func didReceiveAPIResults(results: NSDictionary) {
        var resultsArr: NSArray = results["results"] as NSArray
        dispatch_async(dispatch_get_main_queue(), {
            self.albums = AlbumInfo.albumsWithJSON(resultsArr)
            self.tableView!.reloadData()
            // turn off network activity
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        })
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        switch segue.identifier! {
        case "AlbumToDisplay":
            if var secondViewController = segue.destinationViewController as? PlayItemViewController {
                if var cell = sender as? PlayTableViewCell {
                    var albumIndex = tableView!.indexPathForSelectedRow()!.row
                    //var selectedAlbum = self.albums[albumIndex]
                    //secondViewController.albumInfo = selectedAlbum
                    var selectedAlbum = self.peripehralNameList[albumIndex]
                    secondViewController.BLEName = selectedAlbum
                }
            }
        default:
            break
        }
    }
    
    ///////////// bluetooth /////////////
    // Invoked when the central manager’s state is updated (required)
    func centralManagerDidUpdateState(central: CBCentralManager!) {
        if central.state == .PoweredOn {
            NSLog("TableView: Central ON")
            // scanning available bluetooth devices
            centralManager.stopScan()
            centralManager.scanForPeripheralsWithServices([self.serviceUUID!], options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])
            //centralManager.scanForPeripheralsWithServices(nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])
        }
    }
    
    // Invoked when the central manager discovers a peripheral while scanning
    func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: [NSObject : AnyObject]!, RSSI: NSNumber!) {
        
        //////////// list available peripheral /////////
        if (peripheral != nil) {
            var BLEName:NSString! = peripheral!.valueForKey("name") as NSString
            if (!contains(peripehralNameList, BLEName)) {
                peripehralNameList.append(BLEName)
                println(BLEName)
                self.tableView!.reloadData()
            }
        }
        ////////////////////////////////////////////////
    }
    //////////////////////////////
    
    /*override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Table view data source
    
    override func numberOfSectionsInTableView(tableView: UITableView!) -> Int {
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
