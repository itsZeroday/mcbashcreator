# Minecraft BASH Creator
A simple bash script for Minecraft servers. Allows for you to slightly automate the creation of Minecraft servers without having to manually download and install the jar files within the Linux terminal. 

I made this as a way to experiment with scripting and bash, and to help myself automate some of the work that I do with regards to creating Minecraft servers. 

Features:
Allows the creation of Fabric, Forge, and Vanilla servers through the Linux command line. Automatically generates a directory, server.properties, and variables.txt file. Automatically creates a tmux session when running ./start.sh.

Known issues:

* Forge ./start.sh not working. Currently working on a fix, but can be bypassed by running the created ./run.sh instead. This won't create a tmux session, but will be able to get you running the server off the bat.
* Start server not working.
* Backups may or may not be working correctly. 

Usage:

https://github.com/user-attachments/assets/ead4fa12-d2f7-4021-af7e-335a1843d41d

I am not affiliated with Minecraft, Mojang, Fabric, or Forge.
