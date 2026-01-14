# Pocket Trilium

**Run Trilium on Android.**

![logo](docs/logo.png)

This project is inspired by and heavily modified from the [Cateners/tiny_computer](https://github.com/Cateners/tiny_computer) project.

## Overview

Pocket Trilium allows you to run the powerful [Trilium Notes](https://github.com/zadam/trilium) app on Android devices. While originally based on the [tiny_computer](https://github.com/Cateners/tiny_computer) project, this version has undergone significant modifications to better suit my needs.

## Hints

- Create a folder named trilium-data in your phone’s internal storage, or alternatively, copy the trilium-data folder from your desktop client to your phone.
- For Android 12+ devices, you may need to disable the `Stop restricting child processes` option in `Developer Options` of your system.

## Known issues

Sometimes the app will not start correctly, with error like `double free or corruption`, just kill the app and try to start again several times.

## Improvements

- The APK size has reduced from over 1GB with 4GB of data to approximately 360MB with 1GB of data. Additionally, the initial startup time has decreased dramatically.
- Image upload is now working in the app.

## Credits

A big thank you to the [Cateners/tiny_computer](https://github.com/Cateners/tiny_computer) project for the foundational work. The initial code for this project was based on the following commit: [6425e04](https://github.com/Cateners/tiny_computer/tree/6425e0443efce97b9882c76294bd4271daf39996).

While I’ve made many changes to adapt the project to my use case, I decided to start a new repository instead of maintaining it as a fork, since the goals of this project diverged significantly from the original.

## License

This project is licensed under the **GNU Affero General Public License v3.0**. See the [LICENSE](LICENSE) file for more details.