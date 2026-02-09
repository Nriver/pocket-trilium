# 📱 Pocket Trilium

<p align="center">
** English ** | <a href="README_CN.md">简体中文</a>
</p>

**Run full-featured Trilium on Android. Take your second brain with you, right in your pocket :)**

[<img src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png" alt="Get it on Google Play" height="58">](https://play.google.com/store/apps/details?id=nriver.pocket.trilium)

Please stand up and stretch your body for a while if you see this message :)

[![Support Me on Ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/nriver)

<img src="docs/logo.png" width="200" />

This project is inspired by and heavily modified from the [Cateners/tiny_computer](https://github.com/Cateners/tiny_computer) project.

# 📝 Overview

Pocket Trilium allows you to run the powerful [Trilium Notes](https://github.com/zadam/trilium) app on Android devices. While originally based on the [tiny_computer](https://github.com/Cateners/tiny_computer) project, this version has undergone significant modifications to better suit my needs.

# Screenshots

Run Trilium on your phone.

<img src="docs/screenshot_1.jpg" width="200"/>

You can choose your Trilium version on first start.

<img src="docs/screenshot_2.jpg" width="200"/>

<img src="docs/screenshot_3.jpg" width="200"/>

<img src="docs/screenshot_4.jpg" width="200"/>



# Features

- [x] Choose Trilium version
- [x] Works offline
- [x] Copy `trilium-data` to phone and use it directly
- [x] Sync data with Trilium Server
- [x] You can access pocket trilium with http://your-phone-ip:8080 on your computer in the same wifi
- [x] Image upload from phone works now
- [x] `Back` button/gesture works in Trilium page now
- [x] Reinstall Trilium to upgrade
- [x] Manually clear cache

# ⚙️ Setup Instructions

1. **The `trilium-data` Folder**:

  * You can setup the sync like other Trilium client do. Or, you can copy the `trilium-data` folder from your desktop client to your phone.
  * With Pocket Trilium open in the background, open android system's built-in File Manager (com.android.documentsui). Some system may hide this app by default, you can access it with https://github.com/sdex/ActivityManager

<img src="docs/activity_manager_1.jpg.jpg" width="200"/>

<img src="docs/activity_manager_2.jpgc.jpg" width="200"/>

  * You can find Pocket Trilium's container storage in the left hamburger.

<img src="docs/screenshot_documents_provider.jpg" width="200"/>
 
  * Copy your `trilium-data` into Pocket Trilium's `/0/home/pocket/` folder, restart Pocket Trilium, it will read the data from `/0/home/pocket/trilium-data`.

# 🚧 Known issues

## ❌ App Fails to Start Occasionally

If the app fails to start and you encounter an error such as `double free or corruption`, I've added a retry mechanism to start trilium for 10 times automatically if this happens.

If that does not work for you, try the following:

1. Force close the app.
2. Wait a few seconds to allow the system to terminate any associated processes.
3. Restart the app.

If needed, repeat this process a few times. The app should eventually start successfully.

## Child process limitation

If you're using an Android 12+ device, you may need to disable the "Stop restricting child processes" option in the `Developer Options` menu.

# 🚀 Improvements

- The APK size has reduced from over 1GB with 4GB of data to approximately 360MB with 1GB of data. Additionally, the first time startup time has decreased dramatically.
- Image upload is now working in the app.

# 🎉 Credits

A huge thank you to the [Cateners/tiny_computer](https://github.com/Cateners/tiny_computer) project for laying the groundwork for this project. The initial code for **Pocket Trilium** was based on the following commit: [6425e04](https://github.com/Cateners/tiny_computer/tree/6425e0443efce97b9882c76294bd4271daf39996).

While I’ve made many changes to adapt the project to my use case, I decided to start a new repository instead of maintaining it as a fork, since the goals of this project diverged significantly from the original.

Thank [Zadam](https://github.com/zadam) for creating the wonderful Trilium in the first place. Thanks to everyone in the Trilium community.

And some credit to my old studies years ago :) [Tutorial to Run Trilium Server in Termux on Android](https://github.com/orgs/TriliumNext/discussions/4542) and [Tutorial: Run TriliumNext Server in Termux on Android](https://github.com/orgs/TriliumNext/discussions/5992).

# 🙏 Closed Testing Thanks

A big thank you to everyone who participated in the Google Play closed testing of **Pocket Trilium**.

Your feedback, bug reports, and suggestions were incredibly helpful and directly influenced the stability and usability of the app before its public release.

The following names are provided voluntarily by the testers (nicknames or real names), listed in no particular order:

- Icixy
- 2sr.fun
- hishuxs
- ziven要加油啊
- 蓝天龙
- 辰星
- zm
- hikit
- YIGEHAOR8.
- Neuro
- 刘世杰
- catalpa
- 信
- 阿华田
- 欧神小白
- 腐草
- 风中笑
- Yida
- Cleavory
- AT
- 天涯056
- 卑以自牧
- joshooear
- 1v7w
- 李重茂
- Black bat 3625
- TonyMin
- 冰
- 小辉哥
- 浸月
- T_L
- Bry
- sang
- nsf

And thanks as well to all testers who chose to remain anonymous — your support is equally appreciated ❤️


# 📝 License

This project is licensed under the **GNU Affero General Public License v3.0**. See the [LICENSE](LICENSE) file for more details.

# 💖 Donation

Hello! If you appreciate my creations, kindly consider backing me. Your support is greatly appreciated. Thank you!

Ko-fi:  
[![Support Me on Ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/nriver)

Alipay:  
![Alipay](https://github.com/Nriver/trilium-translation/raw/main/docs/alipay.png)

Wechat Pay:  
![Wechat Pay](https://github.com/Nriver/trilium-translation/raw/main/docs/wechat_pay.png)
