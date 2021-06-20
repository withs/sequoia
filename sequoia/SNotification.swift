//
//  SNotification.swift
//  sequoia
//
//  Created by aielove on 20/06/2021.
//

import SwiftUI
import UserNotifications

class NotificationDelegate: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.badge, .banner])
    }
}

struct Notification {
    let text: String
    let title: String
    
    public func execute() {
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge]) { success, error in
            if success {

                let content = UNMutableNotificationContent()
                content.title = title
                content.sound = UNNotificationSound.default

                content.body = text
                
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)

                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                DispatchQueue.main.async {
                    UIApplication.shared.applicationIconBadgeNumber += 1
                }
                UNUserNotificationCenter.current().add(request)
            } else if let error = error {
                print(error.localizedDescription)
            }
            
        }
        
    }
}
