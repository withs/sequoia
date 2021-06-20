//
//  STiktokMananger.swift
//  sequoia
//
//  Created by aielove on 20/06/2021.
//

import SwiftUI
import Photos
import AVKit

struct welcome: Codable {
    let props: props
    
    struct video: Codable {
        let playAddr: String
        let downloadAddr: String
        let cover: String
    }
    
    struct author: Codable {
        let nickname: String
    }
    
    struct itemStruct: Codable {
        let video: video
        let author: author
        let desc, id: String
        let createTime: Int
    }
    
    struct itemInfo: Codable {
        let itemStruct: itemStruct
    }
    
    struct pageProps: Codable {
        let itemInfo: itemInfo
    }
    
    struct props: Codable {
        let pageProps: pageProps
    }
}

enum downloaderErrors: Error {
    case InvalidUrlGiven
    case JsonScrapFailed
    case JsonParseFailed
    case DownloadVideoForbiden
    case VideoDownloadFailed
    case VideoSaveFailed
    case CoverSaveFailed
}

class TiktokDownloader {
    let videoUrl: String
    var fileName: String? = nil
    var coverFile: String? = nil
    var dataFile: String? = nil
    
    var img: VImageLoader? = nil
    
    init(withUrl: String) {
        videoUrl = withUrl
        //try! self.download() { result in }
    }
    
    private func scrapJson(content: String) -> String? {
        var json: String?
        var jsond = content.components(separatedBy: "id=\"__NEXT_DATA__\"")
        if jsond.indices.contains(1) {
            jsond = jsond[1].components(separatedBy: "crossorigin=\"anonymous\">")
            if jsond.indices.contains(1) {
                jsond = jsond[1].components(separatedBy: "</script>")
                if jsond.indices.contains(0) {
                    json = jsond[0]
                } else { json = nil }
            } else { json = nil  }
        } else { json = nil  }
        
        return json
    }
    
    public func download(completion: @escaping (Result<Tiktok, downloaderErrors>) -> Void) throws {
        
        guard let url = URL(string: videoUrl) else {
            completion(.failure(.InvalidUrlGiven))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.tiktok.com/", forHTTPHeaderField: "Referer")
        request.setValue("bytes=0-", forHTTPHeaderField: "Range")
        
        let dataTask = URLSession.shared.dataTask(with: request) { data, response, error in
            
            if let data = data {
                let html = String(data: data, encoding: .utf8)!
                
                guard let json = self.scrapJson(content: html) else {
                    completion(.failure(.JsonScrapFailed))
                    return
                }
                
                let data = String(json).data(using: .utf8)!
                
                let dot: welcome?
                do {
                    dot = try JSONDecoder().decode(welcome.self, from: data)
                } catch {
                    completion(.failure(.JsonParseFailed))
                    return
                }
                
                guard let dot = dot else {
                    completion(.failure(.JsonParseFailed))
                    return
                }
                
                let videoId = dot.props.pageProps.itemInfo.itemStruct.id
                let videoCreatedTime = dot.props.pageProps.itemInfo.itemStruct.createTime
                
                self.dataFile = "\(videoId)-\(videoCreatedTime).json"
                let UUU: URL = baseDocUrl.appendingPathComponent("tiktoks/data/\(self.dataFile!)")
                let jsonData = try! JSONEncoder().encode(dot)
                let jsonString = String(data: jsonData, encoding: .utf8)!
                try! jsonString.write(to: UUU, atomically: true, encoding: .utf8)
                
                let dlAddr = dot.props.pageProps.itemInfo.itemStruct.video.downloadAddr
                request.url = URL(string: dlAddr)!
                HTTPCookieStorage.shared.setCookie(HTTPCookie(properties: [.domain: dlAddr, .path: "/", .name: "tt_webid", .value: "6972893547414586885", .secure: "FALSE", .discard: "TRUE"])!)
                HTTPCookieStorage.shared.setCookie(HTTPCookie(properties: [.domain: dlAddr, .path: "/", .name: "tt_webid_v2", .value: "6972893547414586885", .secure: "FALSE", .discard: "TRUE"])!)
                
                let videoTask = URLSession.shared.dataTask(with: request) { data, response, error in
                    
                    if let response = response as? HTTPURLResponse {
                        if response.statusCode == 206 {
                            if let data = data {
                                
                                self.fileName = "\(videoId)-\(videoCreatedTime).mp4"
                                let UUU: URL = baseDocUrl.appendingPathComponent("tiktoks/\(self.fileName!)")
                                print("downloading \(self.fileName!)")
                                do {
                                    try data.write(to: UUU)
                                    //try self.saveToPhotos()
                                } catch {
                                    completion(.failure(.VideoSaveFailed))
                                    return
                                }
                                completion(.success(Tiktok(withFileName: "\(videoId)-\(videoCreatedTime)", withData: dot)))
                                
                            }
                        } else {
                            completion(.failure(.DownloadVideoForbiden))
                        }
                    }
                }
                videoTask.resume()
                
                let coverAddr = dot.props.pageProps.itemInfo.itemStruct.video.cover
                request.url = URL(string: coverAddr)!
                HTTPCookieStorage.shared.setCookie(HTTPCookie(properties: [.domain: coverAddr, .path: "/", .name: "tt_webid", .value: "6972893547414586885", .secure: "FALSE", .discard: "TRUE"])!)
                HTTPCookieStorage.shared.setCookie(HTTPCookie(properties: [.domain: coverAddr, .path: "/", .name: "tt_webid_v2", .value: "6972893547414586885", .secure: "FALSE", .discard: "TRUE"])!)
                
                let imageTask = URLSession.shared.dataTask(with: request) { data, response, error in
                    if let data = data {
                        
                        self.coverFile = "\(videoId)-\(videoCreatedTime).jpg"
                        let UUU: URL = baseDocUrl.appendingPathComponent("tiktoks/covers/\(self.coverFile!)")
                        print("downloading cover\(self.coverFile!)")
                        do {
                            try data.write(to: UUU)
                            //try self.saveToPhotos()
                        } catch {
                            completion(.failure(.CoverSaveFailed))
                            return
                        }
                    }
                }
                imageTask.resume()
            }
        }
        dataTask.resume()
    }
}


struct Tiktok {
    var data: welcome? = nil
    var fileName: String
    var coverFile: String
    var dataFile: String
    var vImg: VImageLoader? = nil
    
    enum fileType {
        case data
        case video
        case cover
    }
    
    init(withFileName: String, withData: welcome? = nil) {
        fileName = "\(withFileName).mp4"
        coverFile = "\(withFileName).jpg"
        dataFile = "\(withFileName).json"
        
        if withData == nil {
            let dataFileUrl = baseDocUrl.appendingPathComponent("tiktoks/data/\(dataFile)")
            let dataFile = try! String(contentsOfFile: dataFileUrl.relativePath)
            
            data = try! JSONDecoder().decode(welcome.self, from: dataFile.data(using: .utf8)!)
        } else {
            data = withData
        }
        loadCover()
    }
    
    public func url(forFile: fileType) -> URL {
        
        switch forFile {
        case .video:
            return baseDocUrl.appendingPathComponent("tiktoks/\(fileName)")
        case .data:
            return baseDocUrl.appendingPathComponent("tiktoks/data/\(dataFile)")
        case .cover:
            return baseDocUrl.appendingPathComponent("tiktoks/covers/\(coverFile)")
        }
    }
    
    public mutating func loadCover(){
        if let data = data {
            vImg = VImageLoader(withUrl: url(forFile: .cover).relativeString , size: 160, data: data, withVideoUrl: url(forFile: .video), bundleNames: ["f": fileName, "d": dataFile, "c": coverFile])
        }
    }
    
}

struct VImageLoader: View {
    
    public var withUrl: String
    private var loaded: Bool
    @State private var imgData: UIImage? = nil
    @State var isPresented = false
    
    @State var deleted = false
    
    var data: welcome
    let videoUrl: URL
    var videoPlayer: AVPlayer
    var bundleNames: [String: String]
    
    @State var playerState = false
    
    public let size: CGFloat
    
    init(withUrl: String, size: CGFloat, data: welcome, withVideoUrl: URL, bundleNames: [String:String]) {
        
        self.withUrl = withUrl
        self.loaded = false
        self.size = size
        self.data = data
        self.videoUrl = withVideoUrl
        self.videoPlayer = AVPlayer(url:  videoUrl)
        self.bundleNames = bundleNames
    }
    
    public func saveToPhotos() throws {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoUrl)
        }) { saved, error in
            if saved {
                let succesNotif = Notification(text: "Successfully saved to photo", title: "Info")
                succesNotif.execute()
            }
            if (error != nil) {
                let errNotif = Notification(text: "Failed to save to photo", title: "Error")
                errNotif.execute()
            }
        }
    }
    
    func getImage() {
        let url = URL(string: withUrl)!
        let data = try! Data(contentsOf: url)
        self.imgData = UIImage(data:data)!
    }
    
    var body: some View {
        
        if deleted {
            
        } else {
            if imgData != nil {
                Image(uiImage: imgData!)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: /*@START_MENU_TOKEN@*/25.0/*@END_MENU_TOKEN@*/))
                    .shadow(radius: 7)
                    .sheet(isPresented: $isPresented, content: {
                        Text(data.props.pageProps.itemInfo.itemStruct.author.nickname)
                            .font(.title)
                            .bold()
                            .padding(.top, 20)
                        
                        VideoPlayer(player: videoPlayer)
                            .shadow(radius: 20)
                            .frame(height: 665)
                            .onAppear() {
                                videoPlayer.play()
                                playerState.toggle()
                            }
                            .onDisappear() {
                                videoPlayer.pause()
                            }
                            .onTapGesture {
                                if playerState {
                                    videoPlayer.pause()
                                    playerState.toggle()
                                } else {
                                    videoPlayer.play()
                                    playerState.toggle()
                                }
                            }
                    })
                    .onTapGesture  {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        self.isPresented.toggle()
                    }
                    .contentShape(RoundedRectangle(cornerRadius:25))
                    .contextMenu {
                        VStack {
                            Button(action: {
                                try! saveToPhotos()
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            }) {
                                Label("Save to photo", systemImage: "square.and.arrow.down")
                            }
                            Button(action: {
                                    try! FileManager.default.removeItem(at: baseDocUrl.appendingPathComponent("tiktoks/\(bundleNames["f"]!)"))
                                    try! FileManager.default.removeItem(at: baseDocUrl.appendingPathComponent("tiktoks/data/\(bundleNames["d"]!)"))
                                    try! FileManager.default.removeItem(at: baseDocUrl.appendingPathComponent("tiktoks/covers/\(bundleNames["c"]!)"))
                                
                                    deleted = true
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                            }, label: {
                                Label("Delete", systemImage: "trash").background(Color(.red))
                                
                            })
                            
                        }
                    }
            } else {
                Image("1")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: /*@START_MENU_TOKEN@*/25.0/*@END_MENU_TOKEN@*/))
                    .shadow(radius: 7)
                    .onAppear {
                        if imgData == nil {
                            DispatchQueue.global(qos: .userInitiated).async {
                                self.getImage()
                            }
                        }
                    }
            }
        }
        
        
        
        
    }
    
}
