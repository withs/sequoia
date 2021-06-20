//
//  ContentView.swift
//  sequoia
//
//  Created by aielove on 20/06/2021.
//

import SwiftUI


var size: CGFloat = 160
let baseDocUrl = try! FileManager.default.url(for: .documentDirectory, in: .allDomainsMask, appropriateFor: nil, create: true)


struct ContentView: View {
    @State var TikData: Array<Tiktok> = []
    
    @StateObject var notifDelegate = NotificationDelegate()
    
    // min | size
    // 120 | 160 -> 2
    // 110 | 105 -> 3
    // 80  | 75  -> 4
    // UIScreen.main.bounds.size.width - 25 | 200 -> 1
    
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 15) {
                    if TikData.count == 0 {
                        Text("There is non video saved")
                    } else {
                        ForEach((0..<TikData.count), id: \.self) {
                            TikData[$0].vImg
                        }
                    }
                }
                .padding(.horizontal, 12.5)
            }
            .navigationBarTitle("Saved")
            .toolbar() {
                Image(systemName: "plus.app")
                    .font(.title)
                    .onTapGesture {
                        DispatchQueue.global(qos: .userInitiated).async {
                            print("eeee")
                            guard let clip = UIPasteboard.general.string else {
                                return
                            }
                            print(clip)
                            let dlr = TiktokDownloader(withUrl: clip)
                            try! dlr.download() { result in
                                switch result {
                                case .success(let r):
                                    self.TikData.append(r)
                                    let succesNotif = Notification(text: "Successfully downloaded", title: "Info")
                                    succesNotif.execute()
                                case .failure(let err):
                                    switch err {
                                    case .InvalidUrlGiven:
                                        let errsNotif = Notification(text: "The url you gave is incorrect", title: "Error")
                                        errsNotif.execute()
                                    case .VideoSaveFailed, .DownloadVideoForbiden, .VideoDownloadFailed:
                                        let errsNotif = Notification(text: "Failed to download video", title: "Error")
                                        errsNotif.execute()
                                    default:
                                        let errsNotif = Notification(text: "Generic error", title: "Error")
                                        errsNotif.execute()
                                    }
                                }
                            }
                            UINotificationFeedbackGenerator().notificationOccurred(.success)                            
                        }
                    }
            }
            .onAppear() {
                let tiktokFolder: URL = baseDocUrl.appendingPathComponent("tiktoks")
                let dataFolder: URL = baseDocUrl.appendingPathComponent("tiktoks/data")
                let coverFolder: URL = baseDocUrl.appendingPathComponent("tiktoks/covers")
                
                do {
                    try FileManager.default.createDirectory(at: tiktokFolder, withIntermediateDirectories: true)
                    try FileManager.default.createDirectory(at: dataFolder, withIntermediateDirectories: true)
                    try FileManager.default.createDirectory(at: coverFolder, withIntermediateDirectories: true)
                } catch {}
                
                let strPath = baseDocUrl.appendingPathComponent("tiktoks").relativePath
                let content = try! FileManager.default.contentsOfDirectory(atPath: strPath)
                let savedList = content.filter{ ["covers", "data"].contains($0) != true }.map { $0.split(separator: ".")[0] }
                self.TikData = savedList.map { Tiktok(withFileName: String($0))  }
                
                UNUserNotificationCenter.current().delegate =  notifDelegate
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
        }
        
    }
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}



