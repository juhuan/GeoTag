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

    /// Use the embedded copy of exiftool to update the geolocation metadata
    /// in the file containing the passed image
    /// - Parameter imageData: the image to update.  imageData contains the URL
    ///     of the original file plus the assigned location.
    /// - Returns: ExifTool exit status
    func updateLocation(from imageData: ImageData) -> Int32 {
        // ExifTool latitude and longitude exiftool argument names
        var latArg = "-GPSLatitude="
        var latRefArg = "-GPSLatitudeRef="
        var lonArg = "-GPSLongitude="
        var lonRefArg = "-GPSLongitudeRef="
        // ExifTool GSPDateTime arg storage
        var gpsDArg = ""
        var gpsTArg = ""

        // ExifTool latitude, longitude, and date/time argument values
        if let location = imageData.location {
            var lat = location.latitude
            if lat < 0 {
                latRefArg += "S"
                lat = -lat
            } else {
                latRefArg += "N"
            }
            latArg += "\(lat)"

            var lon = location.longitude
            if lon < 0 {
                lonRefArg += "W"
                lon = -lon
            } else {
                lonRefArg += "E"
            }
            lonArg += "\(lon)"

            // set GPS date/time stamp for current location if enabled
            if Preferences.dateTimeGPS() {
                gpsDArg = "-GPSDateStamp="
                gpsTArg = "-GPSTimeStamp="
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

    // return a date and time stamp of the date the image was taken including
    // time zone indication of +/-hh:mm
    //
    // Nil is returned if there was no date/time original or we couldn't get the
    // appropriate time zone from image geolocation data.
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
