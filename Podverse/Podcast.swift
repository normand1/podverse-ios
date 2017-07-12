//
//  Podcast.swift
//  Podverse
//
//  Created by Creon on 12/24/16.
//  Copyright © 2016 Podverse LLC. All rights reserved.
//

import Foundation
import CoreData
import UIKit

class Podcast: NSManagedObject {
    @NSManaged public var feedUrl: String
    @NSManaged public var imageData: Data?
    @NSManaged public var imageThumbData: Data?
    @NSManaged public var imageUrl: String?
    @NSManaged public var author: String?
    @NSManaged public var link: String? // generally the home page
    @NSManaged public var itunesImage: Data?
    @NSManaged public var itunesImageUrl: String?
    @NSManaged public var lastBuildDate: Date?
    @NSManaged public var lastPubDate: Date?
    @NSManaged public var summary: String?
    @NSManaged public var title: String
    @NSManaged public var categories: String?
    @NSManaged public var episodes: Set<Episode>
    
    func addEpisodeObject(value: Episode) {
        self.mutableSetValue(forKey: "episodes").add(value)
    }
    
    func removeEpisodeObject(value: Episode) {
        self.mutableSetValue(forKey: "episodes").remove(value)
    }
    
    static func retrievePodcastByFeedUrl(feedUrlString: String) -> Podcast? {
        let moc = CoreDataHelper.createMOCForThread(threadType: .mainThread)
        let predicate = NSPredicate(format: "feedUrl == %@", feedUrlString)
        let podcastSet = CoreDataHelper.fetchEntities(className: "Podcast", predicate: predicate, moc:moc) as! [Podcast]
        if podcastSet.count > 0 {
            return podcastSet[0]
        } else {
            return nil
        }
    }
    
    
    static func retrievePodcastUIImage(podcastFeedUrl: String?, podcastImageUrl: String?, managedObjectId: NSManagedObjectID?, completion: @escaping (_ podcastImage: UIImage?) -> Void) {
        DispatchQueue.global().async {
            var cellImage:UIImage?
            
            if let imageUrl = podcastImageUrl {
                if let imageData = retrievePodcastImageData(feedUrl: podcastFeedUrl, imageUrl: imageUrl, managedObjectId: managedObjectId) {
                    cellImage = podcastImageOrDefault(imageData: imageData)
                }
            } else {
                cellImage = UIImage(named: "PodverseIcon")
            }
            
            completion(cellImage)
        }
    }
    
    static func podcastImageOrDefault (imageData: Data) -> UIImage? {
        if let image = UIImage(data: imageData) {
            return image
        } else {
            return UIImage(named: "PodverseIcon")
        }
    }
    
    static func retrievePodcastImageData(feedUrl: String?, imageUrl: String?, managedObjectId: NSManagedObjectID?) -> Data? {
        let moc = CoreDataHelper.createMOCForThread(threadType: .mainThread)
        
        if let managedObjectId = managedObjectId {
            if let podcast = CoreDataHelper.fetchEntityWithID(objectId: managedObjectId, moc: moc) as? Podcast {
                if let imageData = podcast.imageData {
                    return imageData
                }
            }
        } else if let feedUrl = feedUrl {
            let predicate = NSPredicate(format: "feedUrl == %@", feedUrl)
            if let podcastSet = CoreDataHelper.fetchEntities(className: "Podcast", predicate: predicate, moc:moc) as? [Podcast] {
                if podcastSet.count > 0 {
                    let podcast = podcastSet[0]
                    if let imageData = podcast.imageData {
                        return imageData
                    }
                }
            }
        } else if let podcastImageUrl = imageUrl, let url = URL(string: podcastImageUrl) {
            do {
                return try Data(contentsOf: url)
            }
            catch {
                print("No Image Data at give URL")
            }
        }
        
        return nil
    }
}
