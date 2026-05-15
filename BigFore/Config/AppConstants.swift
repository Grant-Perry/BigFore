//
//  AppConstants.swift
//  BigFore
//
//  Created by Gp. on 5/15/26.
//

import SwiftUI

var currentAppVersion: String {
   let marketingVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
   let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String

   if let buildNumber, !buildNumber.isEmpty {
	  return "v\(marketingVersion)[\(buildNumber)]"
   }

   return "v\(marketingVersion)"
}
