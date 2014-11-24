//
//  BookInfo.swift
//  ReDrawBook2
//
//  Created by Ding Xu on 11/23/14.
//  Copyright (c) 2014 Ding Xu. All rights reserved.
//

import Foundation

class BookInfo {
    var title: String
    var description: String
    var coverImage: UIImage?
    var pagesNum: Int
    
    init(title: String, description: String, coverImage: UIImage?, pagesNum: Int) {
        self.title = title
        self.description = description
        self.coverImage = coverImage
        self.pagesNum = pagesNum
    }
}

class PageInfo {
    var pageTitle: String
    var pageIndex: Int
    var pageImage: UIImage
    
    init(title: String, index: Int, pageImage: UIImage) {
        self.pageTitle = title
        self.pageIndex = index
        self.pageImage = pageImage
    }
}
