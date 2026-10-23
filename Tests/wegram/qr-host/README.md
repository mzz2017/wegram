# QR application host

Run `//submodules/TelegramPresentationData:WegramQrHostedTests` through the existing `build-system/Make/Make.py test` command and the local simulator configuration.

This test-only UIKit app provides an application rendering environment for Core Image. It contains no account, API configuration, authentication or network requests. Keep Display and QrCode linked into the executable: first loading AsyncDisplayKit from the injected XCTest bundle can deadlock against UIKit startup on the current iOS 27 runtime.

The strict test requires an independent Core Image control to render and decode, then checks the original production QR generator (`backgroundColor: nil`, `.cutout`, correction level Q) for two fixture links at 216 and 280 pt. It composites an avatar placeholder on white, checks the exact decoded link, and also decodes a PNG made with the production card view. The checks run without an artifact output directory; PNG files are optional evidence. Failures must fail this target rather than skip.

The ordinary component target retains the four card geometry, privacy, expiry and filename checks. Actual account links, temporary token refresh, camera scanning and PhotoKit saving still require separate runtime validation.
