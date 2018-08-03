module.exports = function (context) {
    var fs = context.requireCordovaModule("fs");
    var linkPath = "plugins/com.outsystems.plugins.appfeedback/src/ios/MobileECT/OutSystemsMobileECT.framework/";
    var targetPath = "Versions/A/";

    if(!fs.existsSync(linkPath + 'OutSystemsMobileECT')){
        fs.symlinkSync(targetPath + 'Headers/', linkPath + 'Headers', 'dir');
        fs.symlinkSync(targetPath + 'OutSystemsMobileECT', linkPath + 'OutSystemsMobileECT', 'file');
    }
}