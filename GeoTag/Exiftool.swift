//
//  Exiftool.swift
//  GeoTag
//
//  Created by Marco S Hyman on 7/15/16.
//
// Copyright 2016-2018 Marco S Hyman
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in the
// Software without restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the
// Software, and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
// AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import Foundation
import AppKit

/// manage GeoTag's use of exiftool
struct Exiftool {
    /// singleton instance of this class
    static let helper = Exiftool()

    // URL of the embedded version of ExifTool
    var url: URL

    // Verify access to the embedded version of ExifTool
    init() {
        if let exiftoolUrl = Bundle.main.url(forResource: "ExifTool", withExtension: nil) {
            url = exiftoolUrl.appendingPathComponent("exiftool")
        } else {
            fatalError("The Application Bundle is corrupt.")
        }
    }

    func updateLocation(from imageData: ImageData) -> Int32 {
        // latitude exiftool args
        var latArg = "-GPSLatitude="
        var latRefArg = "-GPSLatitudeRef="
        if var lat = imageData.latitude {
            if lat < 0 {
                latRefArg += "S"
                lat = -lat
            } else {
                latRefArg += "N"
            }
            latArg += "\(lat)"
        }

        // longitude exiftool args
        var lonArg = "-GPSLongitude="
        var lonRefArg = "-GPSLongitudeRef="
        if var lon = imageData.longitude {
            if lon < 0 {
                lonRefArg += "W"
                lon = -lon
            } else {
                lonRefArg += "E"
            }
            lonArg += "\(lon)"
        }

        // GSPDateTime exiftool arg
        var gpsDArg = ""
        var gpsTArg = ""
        if Preferences.dateTimeGPS() {
            gpsDArg = "-GPSDateStamp="
            gpsTArg = "-GPSTimeStamp="
            if imageData.latitude != nil && imageData.longitude != nil {
                if let dto = dtoWithZone(from: imageData) {
                    gpsDArg += "\(dto)"
                    gpsTArg += "\(dto)"
                }
            }
        }

        let exiftool = Process()
        exiftool.standardOutput = FileHandle.nullDevice
        exiftool.standardError = FileHandle.nullDevice
        exiftool.launchPath = url.path
        exiftool.arguments = ["-q", "-m", "-overwrite_original_in_place",
            "-DateTimeOriginal>FileModifyDate", "-GPSStatus=",
            latArg, latRefArg, lonArg, lonRefArg, gpsDArg, gpsTArg,
            imageData.sandboxUrl.path]
        exiftool.launch()
        exiftool.waitUntilExit()
        return exiftool.terminationStatus
    }

    // return a date and time stamp of the date the image was taken
    // converted to Zulu time.
    // Nils are returned if there was no dto or we couldn't get the
    // appropriate time zone from image geo location data.
    private func dtoWithZone(from imageData: ImageData) -> String? {
        if let timeZone = imageData.timeZone, !imageData.date.isEmpty {
            let format = DateFormatter()
            format.dateFormat = "yyyy:MM:dd HH:mm:ss"
            format.timeZone = timeZone
            if let convertedDate = format.date(from: imageData.date) {
                format.dateFormat = "yyyy:MM:dd HH:mm:ss xxx"
                return format.string(from: convertedDate)
            }
        }
        return nil
    }
}
