### Build and Notarize

1. In Xcode, choose Product > Archive

2. In Xcode Organizer, choose Distribute App and follow flow
   for uploading Developer ID app for notarization. The default
   selections should be ok.

3. Wait for notification that app is successfully notarized.

4. Export notarized app to the Desktop.

5. Run ./make_zips_and_appcast.sh

### Resources

[Notarizing Your App Before Distribution](https://developer.apple.com/documentation/security/notarizing_your_app_before_distribution?language=objc)

[Customizing the Notarization Workflow](https://developer.apple.com/documentation/security/notarizing_your_app_before_distribution/customizing_the_notarization_workflow?language=objc)

[Resolving Common Notarization Issues](https://developer.apple.com/documentation/security/notarizing_your_app_before_distribution/resolving_common_notarization_issues?language=objc)

