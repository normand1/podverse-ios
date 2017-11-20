//
//  PVFeedParser.swift
//  Podverse
//
//  Created by Creon on 12/24/16.
//  Copyright © 2016 Podverse LLC. All rights reserved.
//

import Foundation
import CoreData

protocol PVFeedParserDelegate {
    func feedParsingComplete(feedUrl:String?)
    func feedParserStarted()
}

extension PVFeedParserDelegate {
    func feedParserStarted() { }
}

class PVFeedParser {
    
    var feedUrl: String?
    let privateMoc = CoreDataHelper.createMOCForThread(threadType: .privateThread)
    
    var podcast:Podcast?
    var onlyGetMostRecentEpisode: Bool
    var subscribeToPodcast: Bool
    var downloadMostRecentEpisode = false
    var onlyParseChannel = false
    var latestEpisodePubDate:Date?
    var delegate:PVFeedParserDelegate?
    let parsingPodcasts = ParsingPodcasts.shared
    
    init(shouldOnlyGetMostRecentEpisode:Bool, shouldSubscribe:Bool, shouldOnlyParseChannel:Bool) {
        self.onlyGetMostRecentEpisode = shouldOnlyGetMostRecentEpisode
        self.subscribeToPodcast = shouldSubscribe
        self.onlyParseChannel = shouldOnlyParseChannel
    }
    
    func parsePodcastFeed(feedUrlString:String) {

        guard feedUrlString.count > 0 else {
            return
        }
        
        self.parsingPodcasts.addPodcast(feedUrl: feedUrlString)
        
        self.feedUrl = feedUrlString
        let feedParser = ExtendedFeedParser(feedUrl: feedUrlString)
        feedParser.delegate = self
        
        if onlyParseChannel {
            channelInfoFeedParsingQueue.async {
                // This apparently does nothing. The 3rd party FeedParser automatically sets the parsingType to .Full...
                feedParser.parsingType = .channelOnly
                feedParser.parse()
                print("feedParser did start")
            }
        } else {
            feedParsingQueue.async {
                feedParser.parsingType = .full
                feedParser.parse()
                print("feedParser did start")
            }
        }
    }
}

extension PVFeedParser:FeedParserDelegate {
    
    func feedParser(_ parser: FeedParser, didParseChannel channel: FeedChannel) {
        
        if let feedUrlString = channel.channelURL {
            
            // If the podcast has been removed, then abandon parsing.
            if !self.parsingPodcasts.hasMatchingUrl(feedUrl: feedUrlString) {
                return
            }
            
            podcast = CoreDataHelper.retrieveExistingOrCreateNewPodcast(feedUrlString: feedUrlString, moc: self.privateMoc)
        }
        else {
            return
        }
        
        if let podcast = podcast {
            
            if let feedUrlString = channel.channelURL {
                podcast.feedUrl = feedUrlString
            }
            
            if let title = channel.channelTitle {
                podcast.title = title
            }
            
            if let summary = channel.channelDescription {
                podcast.summary = summary
            }
            
            if let iTunesAuthor = channel.channeliTunesAuthor {
                podcast.author = iTunesAuthor
            }
            
            if let podcastLink = channel.channelLink {
                podcast.link = podcastLink
            }
            
            if let imageUrlString = channel.channelLogoURL, let imageURL = URL(string:imageUrlString) {
                podcast.imageUrl = imageURL.absoluteString
                do {
                    podcast.imageData = try Data(contentsOf: imageURL)
                }
                catch {
                    print("No Image Data at give URL")
                }
            }
            
            if let iTunesImageUrlString = channel.channeliTunesLogoURL, let itunesImageURL = URL(string:iTunesImageUrlString) {
                podcast.itunesImageUrl = itunesImageURL.absoluteString
                do {
                    podcast.itunesImage = try Data(contentsOf: itunesImageURL)
                    
                    if podcast.imageData == nil {
                        podcast.imageData = try Data(contentsOf: itunesImageURL)
                        podcast.imageUrl = podcast.itunesImageUrl
                    }
                }
                catch {
                    print("No Image Data at give URL")
                }
            }
            
            if let downloadedImageData = podcast.imageData {
                podcast.imageThumbData = downloadedImageData.resizeImageData()
            }
            else if let downloadedImageData = podcast.itunesImage {
                podcast.imageThumbData = downloadedImageData.resizeImageData()
            }
            
            if let lastBuildDate = channel.channelLastBuildDate {
                podcast.lastBuildDate = lastBuildDate
            }
            
            if let lastPubDate = channel.channelLastPubDate {
                podcast.lastPubDate = lastPubDate
            }
            
            if let categories = channel.channelCategory {
                podcast.categories = categories
            }
            
            self.privateMoc.saveData(nil)
            
        }
        
    }
    
    func feedParser(_ parser: FeedParser, didParseItem item: FeedItem) {

        // This hack is put in to prevent parsing items unnecessarily. Ideally this would be handled by setting feedParser.parsingType to .ChannelOnly, but the 3rd party FeedParser does not let us override the .parsingType I think...
        if self.onlyParseChannel {
            return
        }

        guard let feedUrl = self.feedUrl, let podcast = podcast else {
            // If podcast is nil, then the RSS feed was invalid for the parser, and we should return out of successfullyParsedURL
            return
        }
        
        // If the podcast has been removed, then abandon parsing.
        if !self.parsingPodcasts.hasMatchingUrl(feedUrl: feedUrl) {
            return
        }

        //Do not parse episode if it does not contain feedEnclosures.
        if item.feedEnclosures.count <= 0 {
            return
        }
        
        let mediaUrl = item.feedEnclosures[0].url
        
        // If only parsing for the latest episode, stop parsing after parsing the first episode.
        if onlyGetMostRecentEpisode == true {
            latestEpisodePubDate = item.feedPubDate
            parser.abortParsing()
            return
        }
        
        // If episode already exists in the database, do nothing
        if let episode = Episode.episodeForMediaUrl(mediaUrlString: mediaUrl, managedObjectContext: self.privateMoc), episode.podcast != nil {
            // do nothing
        } else {
            let newEpisodeID = CoreDataHelper.insertManagedObject(className: "Episode", moc: self.privateMoc)
            let newEpisode = CoreDataHelper.fetchEntityWithID(objectId: newEpisodeID, moc: self.privateMoc) as! Episode
            
            // Retrieve parsed values from item and add values to their respective episode properties
            if let title = item.feedTitle { newEpisode.title = title }
            if let summary = item.feedContent { newEpisode.summary = summary }
            if let date = item.feedPubDate { newEpisode.pubDate = date }
            if let link = item.feedLink { newEpisode.link = link }
            if let duration = item.duration { newEpisode.duration = duration }
            
            newEpisode.mediaUrl = item.feedEnclosures[0].url
            newEpisode.mediaType = item.feedEnclosures[0].type
            newEpisode.mediaBytes = NSNumber(value: item.feedEnclosures[0].length)
            if let guid = item.feedIdentifier { newEpisode.guid = guid }
            
            podcast.addEpisodeObject(value: newEpisode)
            
            if self.downloadMostRecentEpisode == true && podcast.shouldAutoDownload() {
                PVDownloader.shared.startDownloadingEpisode(episode: newEpisode)
                self.downloadMostRecentEpisode = false
            }
            
            self.privateMoc.saveData(nil)
            
        }
        
    }
    
    func feedParser(_ parser: FeedParser, successfullyParsedURL url: String) {
        
        self.parsingPodcasts.podcastFinishedParsing()
        
        guard let _ = self.feedUrl, let podcast = podcast else {
            return
        }
        
        let podcastPredicate = NSPredicate(format: "podcast == %@", podcast)
        
        // If subscribing to a podcast, then get the latest episode and begin downloading
        if subscribeToPodcast == true {
            if let latestEpisode = CoreDataHelper.fetchEntityWithMostRecentPubDate(className:"Episode", predicate: podcastPredicate, moc:self.privateMoc) as? Episode {
                if latestEpisode.fileName == nil {
                    PVDownloader.shared.startDownloadingEpisode(episode: latestEpisode)
                    podcast.addToAutoDownloadList()
                }
            }
        }
        
        if let mostRecentEpisode = CoreDataHelper.fetchEntityWithMostRecentPubDate(className:"Episode", predicate: podcastPredicate, moc:self.privateMoc) as? Episode {
            podcast.lastPubDate = mostRecentEpisode.pubDate
            self.privateMoc.saveData(nil)
        }
        
        self.delegate?.feedParsingComplete(feedUrl: podcast.feedUrl)
        
        print("Feed parser has finished!")
    }
    
    func feedParserParsingAborted(_ parser: FeedParser) {
        
        guard let feedUrl = self.feedUrl, let podcast = podcast else {
            self.parsingPodcasts.podcastFinishedParsing()
            self.delegate?.feedParsingComplete(feedUrl:nil)
            return
        }
        
        // If the parser is only returning the latest episode, then if the podcast's latest episode returned is not the same as the latest episode saved locally, parse the entire feed again, then download and save the latest episode
        if let latestEpisodePubDateInRSSFeed = latestEpisodePubDate, self.onlyGetMostRecentEpisode == true {
            let podcastPredicate = NSPredicate(format: "podcast == %@", podcast)
            
            let mostRecentEpisode = CoreDataHelper.fetchEntityWithMostRecentPubDate(className: "Episode", predicate: podcastPredicate, moc: self.privateMoc) as? Episode
            
            if mostRecentEpisode == nil {
                parseAndDownloadMostRecentEpisode(feedUrl: feedUrl)
            } else if let mostRecentEpisode = mostRecentEpisode, let mostRecentPubDate = mostRecentEpisode.pubDate, latestEpisodePubDateInRSSFeed != mostRecentPubDate {
                parseAndDownloadMostRecentEpisode(feedUrl: feedUrl)
            }
            else {
                self.parsingPodcasts.podcastFinishedParsing()
                self.delegate?.feedParsingComplete(feedUrl: feedUrl)
            }
        } else {
            print("No newer episode available, don't download")
        }
    }
    
    func parseAndDownloadMostRecentEpisode (feedUrl: String) {
        self.onlyGetMostRecentEpisode = false
        self.downloadMostRecentEpisode = true
        self.parsePodcastFeed(feedUrlString: feedUrl)
    }
}
