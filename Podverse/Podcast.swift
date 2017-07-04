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
    @NSManaged public var isSubscribed: Bool
    @NSManaged public var isFollowed: Bool
    @NSManaged public var categories: String?
    @NSManaged public var episodes: Set<Episode>
    
    var totalClips:Int {
        get {
            var totalClips = 0
            for episode in episodes {
                totalClips += episode.clips.count
            }
            
            return totalClips
        }
    }
    
    func addEpisodeObject(value: Episode) {
        self.mutableSetValue(forKey: "episodes").add(value)
    }
    
    func removeEpisodeObject(value: Episode) {
        self.mutableSetValue(forKey: "episodes").remove(value)
    }
    
    static func retrieveMediaRefsFromServer(episodeMediaUrl: String? = nil, podcastFeedUrl: String? = nil, onlySubscribed: Bool? = nil, completion: @escaping (_ mediaRefs:[MediaRef]?) -> Void) {
    }

    
    static func retrievePodcastUIImage(item: PlayerHistoryItem, completion: @escaping (_ podcastImage: UIImage?) -> Void) {
        var cellImage:UIImage?
        if let podcastFeedUrl = item.podcastFeedUrl, let imageData = retrievePodcastImageData(feedUrl: podcastFeedUrl, imageUrl: item.podcastImageUrl) {
            if let image = UIImage(data: imageData) {
                cellImage = image
            } else {
                cellImage = UIImage(named: "PodverseIcon")
            }
            completion(cellImage)
        } else {
            cellImage = UIImage(named: "PodverseIcon")
            completion(cellImage)
        }
    }
    
    static func retrievePodcastImageData(feedUrl: String, imageUrl: String?) -> Data? {
        let moc = CoreDataHelper.createMOCForThread(threadType: .mainThread)
        
        let predicate = NSPredicate(format: "feedUrl == %@", feedUrl)
        if let podcastSet = CoreDataHelper.fetchEntities(className: "Podcast", predicate: predicate, moc:moc) as? [Podcast] {
            if podcastSet.count > 0 {
                let podcast = podcastSet[0]
                
                if let imageData = podcast.imageData {
                    return imageData
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
